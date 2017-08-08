require "uuid_pack/version"

module UuidPack

  # calculate bits in number
  def binPow(num)
    pow = 0
    until num >> pow == 0
      pow += 1 
    end
    pow
  end

  #transform string of valid characters to useful array (del = true if we need delimiter)
  def alptoArr alpStr, del
    alpArr = Array.new
    el = alpStr.length
    # max number of bits coding by one character (some characters will be one bit less)
    pow = binPow (el - 1)
    # how many characters will be one bit less
    lowhi = 2 ** pow - el
    # if delimited we can't use last characters
    if del
      el -= 1
      pow = binPow (el - 1)
      lowhi = 2 ** pow - el
      lowhi = -1 if lowhi == 0
      # first element include main data about alphabet and delimiter character
      alpArr.push [lowhi, alpStr[el], pow]
      lowhi = 0 if lowhi == -1
    else
      # first element include main data about alphabet
      lowhi = -1 if lowhi == 0
      alpArr.push [lowhi, '', pow]
      lowhi = 0 if lowhi == -1
    end
    charItem = 0
    # loop by characters and get code for each one
    until charItem == el
      if charItem < lowhi
        alpArr.push [charItem, alpStr[charItem], pow - 1]
      else
        alpArr.push [lowhi + charItem, alpStr[charItem], pow]
      end
      charItem += 1
    end
    alpArr
  end

  # compress UUIDs array
  def alpCompress arr, alpStr, order
    # length of UUID in bits
    lenU = 128

    # compress without delta
    nresult = ''
    alpArr = alptoArr alpStr, false
    pow = alpArr[0][2]
    lowhi = alpArr[0][0]
    # first bit equal 0 => compress without delta
    achr = 0
    rest = 1
    # loop by UUIDs
    arr.each do |item|
      # remove '-' characters from UUID
      curr = item.gsub('-', '').to_i(base=16)
      # get base binary code (BBC)
      achr += (curr << rest)
      # look for number of bits in BBC
      rest = rest + lenU
      # create symbols to compressed string 
      until rest < pow
        powC = pow -1
        code = ((achr & (2 ** powC - 1)) + 2 ** powC).to_s(2).reverse.to_i(base=2) >> 1
        powC += 1 if code >= lowhi
        # decrease number of bits in BBC
        rest -= powC
        # get reverse bits from the end of BBC to create new symbol
        code = ((achr & (2 ** powC - 1)) + 2 ** powC).to_s(2).reverse.to_i(base=2) >> 1
        # add new symbol
        nresult += alpArr.assoc(code)[1]
        # remove used bits from BBC
        achr >>= powC 
      end
    end
    # check if we have tail of BBC
    if rest > 0
      code = ((achr & (2 ** rest - 1)) + 2 ** rest).to_s(2).reverse.to_i(base=2) >> 1
      code <<= pow - rest - 1
      code <<= 1 if code >= lowhi
      # add tail symbol
      nresult += alpArr.assoc(code)[1]
    end

    # compress with delta
    arr = arr.sort
    # first character is delimiter => compress with delta : delimiter (last character in alphabet) always has code of all ones
    dresult = alpArr[-1][1]
    alpArr = alptoArr alpStr, true
    pow = alpArr[0][2]
    if pow > 1
      lowhi = alpArr[0][0]
      prev = 0
      # loop by UUIDs
      arr.each do |item|
        # remove '-' characters from UUID
        curr = item.gsub('-', '').to_i(base=16)
        # calculate delta
        curr -= prev
        prev = item.gsub('-', '').to_i(base=16)
        binlog = binPow curr
        binlog = lenU if binlog >= lenU - pow
        # get BBC for only current UUID
        achr = curr
        # look for number of bits in BBC (also for only current UUID)
        rest = binlog
        # create symbols to compressed string 
        until rest < pow
          powC = pow -1
          code = ((achr & (2 ** powC - 1)) + 2 ** powC).to_s(2).reverse.to_i(base=2) >> 1
          powC += 1 if code >= lowhi
          # decrease number of bits in BBC
          rest -= powC
          # get reverse bits from the end of BBC to create new symbol
          code = ((achr & (2 ** powC - 1)) + 2 ** powC).to_s(2).reverse.to_i(base=2) >> 1
          # add new symbol
          dresult += alpArr.assoc(code)[1]
          # remove used bits from BBC
          achr >>= powC 
        end
        # check if we have tail of BBC for current UUID
        if rest > 0
          code = ((achr & (2 ** rest - 1)) + 2 ** rest).to_s(2).reverse.to_i(base=2) >> 1
          code <<= pow - rest - 1
          code <<= 1 if code >= lowhi
          # add tail symbol for current UUID
          dresult += alpArr.assoc(code)[1]
        end
        # add delimiter if we use less symbols than for whole UUID
        dresult += alpArr[0][1] if binlog < lenU
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
  def alpDecompress str, alpStr
    # length of UUID in bits
    lenU = 128

    result = Array.new
    alpArr = alptoArr alpStr, false
    # check if delta used when compress
    if alpArr.rassoc(str[0])[0] & (2 ** (alpArr.rassoc(str[0])[2] - 1)) != 0
      # delta used
      alpArr = alptoArr alpStr, true
      pow = alpArr[0][2]
      lowhi = alpArr[0][0]
      prev = 0
      item = 1
      achr = 0
      rest = 0
      # loop by symbols of compressed string starting from second (the first is header) to next after last (for BBC length processing after last)
      while item <= str.length
        # we catch delimiter or we get BBC with length equal whole UUID
        if str[item] == alpArr[0][1] || rest >= lenU
          # if BBC length than we need to look to current symbol one more time if it is delimiter
          item -= 1 if rest >= lenU
          # calculate UUID from delta
          achr +=prev
          prev = achr
          # transform UUID to hexadecimal
          curr = (prev).to_s(16)
          # add first characters if UUID start with 0
          curr = '0' * (lenU / 4 - curr.length) + curr
          # add '-' characters from UUID
          curr = curr[0..7] + '-' + curr[8..11] + '-' + curr[12..15] + '-' + curr[16..19] + '-' + curr[20..31] if lenU == 128
          # add new UUID to array
          result.push curr
          achr = 0
          rest = 0
        else
          # if we become last symbol we need no to symbol processing 
          if item < str.length
            # reverse symbol code to BBC bits
            code = (alpArr.rassoc(str[item])[0] + 2 ** alpArr.rassoc(str[item])[2]).to_s(2).reverse.to_i(base=2) >> 1
            # add bits to BBC
            achr += code << rest
            # look for number of bits in BBC
            rest += pow
            rest -= 1 if code < lowhi
          end
        end
        item += 1
      end
    else
      # delta not used
      achr = 0
      rest = 0
      pow = alpArr[0][2]
      lowhi = alpArr[0][0]
      # for first bit processing
      frst = true
      item = 0
      # loop by symbols of compressed string
      while item < str.length
        # reverse symbol code to BBC bits
        code = (alpArr.rassoc(str[item])[0] + 2 ** alpArr.rassoc(str[item])[2]).to_s(2).reverse.to_i(base=2) >> 1
        # add bits to BBC
        achr += code << rest
        # look for number of bits in BBC
        rest += pow
        rest -= 1 if alpArr.rassoc(str[item])[0] < lowhi
        # first bit processing
        if frst
          frst = false
          achr >>= 1
          rest -= 1
        end
        # we get BBC with length equal whole UUID
        if rest >= lenU
          # calculate number of bits in BBC
          rest -= lenU
          # transform UUID to hexadecimal
          curr = (achr & (2 ** lenU - 1)).to_s(16)
          # add first characters if UUID start with 0
          curr = '0' * (lenU / 4 - curr.length) + curr
          # add '-' characters from UUID
          curr = curr[0..7] + '-' + curr[8..11] + '-' + curr[12..15] + '-' + curr[16..19] + '-' + curr[20..31] if lenU == 128
          # add new UUID to array
          result.push curr
          # remove used bits from BBC
          achr >>= lenU
        end
        item +=1
      end
    end
    result
  end
end
