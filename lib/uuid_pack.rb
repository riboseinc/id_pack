require "uuid_pack/version"

# Based on work by Oleksandr Korniienko
module UuidPack

  # calculate bits in number
  def bin_pow(num)
    pow = 0
    pow += 1 until num >> pow == 0
    pow
  end

  # transform string of valid characters to useful array (del = true if we need
  # delimiter)
  def alphanum_to_array(alphanum_string, del)

    alphanum_array = []
    el = alphanum_string.length

    # max number of bits coding by one character (some characters will be one
    # bit less)
    pow = bin_pow (el - 1)

    # how many characters will be one bit less
    lowhi = 2**pow - el

    # if delimited we can't use last characters
    if del
      el    -= 1
      pow    = bin_pow(el - 1)
      lowhi  = 2**pow - el
      lowhi  = -1 if lowhi.zero?
      # first element include main data about alphabet and delimiter character
      alphanum_array.push [lowhi, alphanum_string[el], pow]
    else
      # first element include main data about alphabet
      lowhi = -1 if lowhi.zero?
      alphanum_array.push [lowhi, '', pow]
    end

    lowhi     = 0 if lowhi == -1
    char_item = 0

    # loop by characters and get code for each one
    until char_item == el
      if char_item < lowhi
        alphanum_array.push [char_item, alphanum_string[char_item], pow - 1]
      else
        alphanum_array.push [lowhi + char_item, alphanum_string[char_item], pow]
      end
      char_item += 1
    end
    alphanum_array
  end

  # compress UUIDs array
  def alphanum_compress(arr, alphanum_string, order)
    # length of UUID in bits
    uuid_bit_length = 128

    # compress without delta
    nresult        = ''
    alphanum_array = alphanum_to_array alphanum_string, false
    pow            = alphanum_array[0][2]
    lowhi          = alphanum_array[0][0]

    # first bit equal 0 => compress without delta
    achr = 0
    rest = 1

    # loop by UUIDs
    arr.each do |item|

      # remove '-' characters from UUID
      curr = item.delete('-').to_i(16)

      # get base binary code (BBC)
      achr += (curr << rest)

      # look for number of bits in BBC
      rest += uuid_bit_length

      # create symbols to compressed string
      until rest < pow

        power_c  = pow - 1
        code     = (
          (achr & (2**power_c - 1)) + 2**power_c
        ).to_s(2).reverse.to_i(2) >> 1

        power_c += 1 if code >= lowhi

        # decrease number of bits in BBC
        rest -= power_c

        # get reverse bits from the end of BBC to create new symbol
        code = (
          (achr & (2**power_c - 1)) + 2**power_c
        ).to_s(2).reverse.to_i(2) >> 1

        # add new symbol
        nresult += alphanum_array.assoc(code)[1]

        # remove used bits from BBC
        achr >>= power_c
      end
    end

    # check if we have tail of BBC
    if rest > 0
      code   = ((achr & (2**rest - 1)) + 2**rest).to_s(2).reverse.to_i(2) >> 1
      code <<= pow - rest - 1
      code <<= 1 if code >= lowhi

      # add tail symbol
      nresult += alphanum_array.assoc(code)[1]
    end

    # compress with delta
    arr = arr.sort

    # first character is delimiter => compress with delta : delimiter (last
    # character in alphabet) always has code of all ones
    dresult        = alphanum_array[-1][1]
    alphanum_array = alphanum_to_array alphanum_string, true
    pow            = alphanum_array[0][2]

    if pow > 1
      lowhi = alphanum_array[0][0]
      prev  = 0

      # loop by UUIDs
      arr.each do |item|

        # remove '-' characters from UUID
        curr = item.delete('-').to_i(16)

        # calculate delta
        curr   -= prev
        prev    = item.delete('-').to_i(16)
        binlog  = bin_pow curr
        binlog  = uuid_bit_length if binlog >= uuid_bit_length - pow

        # get BBC for only current UUID
        achr = curr

        # look for number of bits in BBC (also for only current UUID)
        rest = binlog

        # create symbols to compressed string
        until rest < pow
          power_c  = pow - 1
          code     = (
            (achr & (2**power_c - 1)) +
            2**power_c
          ).to_s(2).reverse.to_i(2) >> 1

          power_c += 1 if code >= lowhi

          # decrease number of bits in BBC
          rest -= power_c

          # get reverse bits from the end of BBC to create new symbol
          code = (
            (achr & (2**power_c - 1)) +
            2**power_c
          ).to_s(2).reverse.to_i(2) >> 1

          # add new symbol
          dresult += alphanum_array.assoc(code)[1]

          # remove used bits from BBC
          achr >>= power_c
        end

        # check if we have tail of BBC for current UUID
        if rest > 0
          code   = (
            (achr & (2**rest - 1)) + 2**rest
          ).to_s(2).reverse.to_i(2) >> 1

          code <<= pow - rest - 1
          code <<= 1 if code >= lowhi

          # add tail symbol for current UUID
          dresult += alphanum_array.assoc(code)[1]
        end

        # add delimiter if we use less symbols than for whole UUID
        dresult += alphanum_array[0][1] if binlog < uuid_bit_length
      end
    else
      order = true
    end

    result = nresult

    # get better result or non delta if we need to keep order
    result = dresult if dresult.length < nresult.length && !order
    result
  end

  # decompress UUIDs array
  def alphanum_decompress(str, alphanum_string)
    # length of UUID in bits
    uuid_bit_length = 128

    result = []
    alphanum_array = alphanum_to_array alphanum_string, false

    # check if delta used when compress
    if (
        alphanum_array.rassoc(str[0])[0] &
        (2**(alphanum_array.rassoc(str[0])[2] - 1))
    ) != 0

      # delta used
      alphanum_array = alphanum_to_array alphanum_string, true
      pow            = alphanum_array[0][2]
      lowhi          = alphanum_array[0][0]
      prev           = 0
      item           = 1
      achr           = 0
      rest           = 0

      # loop by symbols of compressed string starting from second (the first is
      # header) to next after last (for BBC length processing after last)
      while item <= str.length

        # we catch delimiter or we get BBC with length equal whole UUID
        if str[item] == alphanum_array[0][1] || rest >= uuid_bit_length

          # if BBC length than we need to look to current symbol one more time
          # if it is delimiter
          item -= 1 if rest >= uuid_bit_length

          # calculate UUID from delta
          achr += prev
          prev = achr

          # transform UUID to hexadecimal
          curr = prev.to_s(16)

          # add first characters if UUID start with 0
          curr = '0' * (uuid_bit_length / 4 - curr.length) + curr

          # add '-' characters from UUID
          curr = [
            curr[0..7],
            curr[8..11],
            curr[12..15],
            curr[16..19],
            curr[20..31],
          ].join('-')

          # add new UUID to array
          result.push curr
          achr = 0
          rest = 0

        # if we become last symbol we need no to symbol processing
        elsif item < str.length

          # reverse symbol code to BBC bits
          code = (
            alphanum_array.rassoc(str[item])[0] + 2**alphanum_array.rassoc(str[item])[2]
          ).to_s(2).reverse.to_i(2) >> 1

          # add bits to BBC
          achr += code << rest

          # look for number of bits in BBC
          rest += pow
          rest -= 1 if code < lowhi

        end

        item += 1

      end

    else
      # delta not used
      achr  = 0
      rest  = 0
      pow   = alphanum_array[0][2]
      lowhi = alphanum_array[0][0]

      # for first bit processing
      frst = true
      item = 0

      # loop by symbols of compressed string
      while item < str.length

        # reverse symbol code to BBC bits
        code =
          (
            alphanum_array.rassoc(str[item])[0] +
            2**alphanum_array.rassoc(str[item])[2]
          )
          .to_s(2).reverse.to_i(2) >> 1

        # add bits to BBC
        achr += code << rest

        # look for number of bits in BBC
        rest += pow
        rest -= 1 if alphanum_array.rassoc(str[item])[0] < lowhi

        # first bit processing
        if frst
          frst = false
          achr >>= 1
          rest -= 1
        end

        # we get BBC with length equal whole UUID
        if rest >= uuid_bit_length

          # calculate number of bits in BBC
          rest -= uuid_bit_length

          # transform UUID to hexadecimal
          curr = (achr & (2**uuid_bit_length - 1)).to_s(16)

          # add first characters if UUID start with 0
          curr = '0' * (uuid_bit_length / 4 - curr.length) + curr

          # add '-' characters from UUID
          curr = [
            curr[0..7],
            curr[8..11],
            curr[12..15],
            curr[16..19],
            curr[20..31],
          ].join('-')

          # add new UUID to array
          result.push curr

          # remove used bits from BBC
          achr >>= uuid_bit_length

        end

        item += 1
      end
    end
    result
  end
end
