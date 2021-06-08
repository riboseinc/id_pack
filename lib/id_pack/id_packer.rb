module IdPack

  # This is a module to encode an integer array into our compressed format.
  # Basically there are only 2 methods in this module, encode and decode.
  #
  # Usage:
  #   encode:
  #     a usual use case of encode is to provide the server with object ids
  #     that have already been fetched and hence we don't need their data to
  #     be returned
  #
  #     Example:
  #
  #       IdPack::IdPacker.new.encode([5, 6, 21, 23, 25]) # => "_F~C_P.V"
  #
  #   decode:
  #     mainly used by the server to convert the compressed string back into
  #     the integer array
  #
  #     Example:
  #
  #       IdPack::IdPacker.new.decode("_F~C_P.V") # => [5, 6, 21, 23, 25]

  class IdPacker

    class InvalidEncodedCharException < StandardError; end

    SPACES_PREFIX = '_'.freeze
    BINARY_PREFIX = '.'.freeze
    RANGE_PREFIX  = '~'.freeze
    WINDOW_SIZE = 10
    EXCLUDE_NIL = true
    ENCODED_NUMBER_CHARS = "#{(('A'..'Z').to_a + ('a'..'z').to_a + ('0'..'9').to_a).join}-".freeze


    # [5, 6, 21, 23, 25]
    # => "_F~C_P.V"
    def encode(array, window_size = WINDOW_SIZE, _exclude_nil = EXCLUDE_NIL, output_charset = ENCODED_NUMBER_CHARS)
      encoded_array = ''

      ranges = convert_numbers_to_ranges array.uniq.sort
      prev_end = 0
      curr_start = 1
      spaces = 0
      group_with_prev = false
      ranges_to_group = []
      binary_number = ''
      decimal_number = 0
      encoded_string = ''

      ranges.each_with_index do |range, _i|
        spaces = range.begin - prev_end

        if group_with_prev
          if range.end - curr_start + 1 == window_size
            ranges_to_group << range
            binary_number = convert_ranges_to_binary_number ranges_to_group
            decimal_number = convert_binary_number_to_decimal_number binary_number
            encoded_string = BINARY_PREFIX + encode_decimal_number(
              decimal_number, output_charset
            )
            encoded_array += encoded_string
            ranges_to_group = []
            group_with_prev = false
          elsif range.end - curr_start + 1 >= window_size
            if ranges_to_group.length == 1
              encoded_string = RANGE_PREFIX + encode_decimal_number(
                ranges_to_group.first.size, output_charset
              )
              encoded_array += encoded_string
            else
              binary_number = convert_ranges_to_binary_number ranges_to_group
              decimal_number = convert_binary_number_to_decimal_number binary_number
              encoded_string = BINARY_PREFIX + encode_decimal_number(
                decimal_number, output_charset
              )
              encoded_array += encoded_string
            end
            ranges_to_group = []
            encoded_string = SPACES_PREFIX + encode_decimal_number(spaces,
                                                                   output_charset)
            encoded_array += encoded_string

            if range.size >= window_size
              encoded_string = RANGE_PREFIX + encode_decimal_number(range.size,
                                                                    output_charset)
              encoded_array += encoded_string
              group_with_prev = false
            else
              ranges_to_group.push range
              curr_start = range.begin
              group_with_prev = true
            end
          else
            ranges_to_group.push range
          end
        else
          if spaces >= 0
            encoded_string = SPACES_PREFIX + encode_decimal_number(spaces,
                                                                   output_charset)
            encoded_array += encoded_string
          end

          if range.size >= window_size
            encoded_string = RANGE_PREFIX + encode_decimal_number(range.size,
                                                                  output_charset)
            encoded_array += encoded_string
          else
            ranges_to_group.push range
            curr_start = range.begin
            group_with_prev = true
          end
        end

        prev_end = range.end
      end

      if ranges_to_group.length == 1
        encoded_string = RANGE_PREFIX + encode_decimal_number(
          ranges_to_group.first.size, output_charset
        )
        encoded_array += encoded_string
      elsif ranges_to_group.length.positive?
        binary_number = convert_ranges_to_binary_number ranges_to_group
        decimal_number = convert_binary_number_to_decimal_number binary_number
        encoded_string = BINARY_PREFIX + encode_decimal_number(decimal_number,
                                                               output_charset)
        encoded_array += encoded_string
      end

      encoded_array
    end

    # "_F~C_P.V"
    # => [5, 6, 21, 23, 25]
    def decode(encoded_caches)
      curr_encoded_string_prefix = nil

      ids = []
      start_id = 0
      encoded_number = ''

      encoded_caches.each_char do |c|
        if [SPACES_PREFIX, BINARY_PREFIX, RANGE_PREFIX].include?(c)
          unless curr_encoded_string_prefix == nil
            ids_to_include, end_id = convert_encoded_number_to_ids(
              curr_encoded_string_prefix, encoded_number, start_id
            )
            ids.concat(ids_to_include)
            start_id = end_id + (c == SPACES_PREFIX ? 0 : 1)
          end
          curr_encoded_string_prefix = c
          encoded_number = ''
        else
          encoded_number = encoded_number + c
        end

      end

      unless curr_encoded_string_prefix == nil
        ids_to_include, end_id = convert_encoded_number_to_ids(
          curr_encoded_string_prefix, encoded_number, start_id
        )
        ids.concat(ids_to_include)
        start_id = end_id + 1
      end

      ids
    rescue InvalidEncodedCharException
      # corrupted encoded_caches, assume nothing cached
      []
    end

    # Input: id_synced_at:
    # {
    #   1 => synced_at_1_timestamp,
    #   2 => synced_at_2_timestamp,
    #   10 => synced_at_10_timestamp, ...
    # }
    #
    # Expected output of sync_str:
    # min_last_synced_at,\
    # "encoded_0",diff_last_synced_at_0,\
    # "encoded_1",diff_last_synced_at_1,\
    # "encoded_2",diff_last_synced_at_2, ...
    def encode_sync_str(id_synced_at)
      min_synced_at = id_synced_at.values.min
      encoded_min_synced_at = LZString.compress_to_encoded_uri_component(min_synced_at.to_s)

      grouped_synced_at = id_synced_at.group_by do |_id, synced_at|
        synced_at
      end

      grouped_synced_at.inject([encoded_min_synced_at]) do |sync_str_arr, (synced_at, ids_group)|
        ids = ids_group.map do |id_group|
          int_id = id_group[0].to_s.to_i

          if int_id && int_id.to_s == id_group[0].to_s
            int_id
          else
            id_group[0].to_s
          end
        end

        joined_ids = if ids.first.is_a?(String)
                       ids.join("").gsub(/-/,
                                         "")
                     else
                       ids.join(",")
                     end

        encoded_indices = LZString.compress_to_encoded_uri_component(joined_ids)
        diff_synced_at = synced_at - min_synced_at
        encoded_diff_synced_at = LZString.compress_to_encoded_uri_component(diff_synced_at.to_s)

        sync_str_arr << "#{encoded_indices},#{encoded_diff_synced_at}"
      end.join(",")
    end

    def decode_sync_str(sync_str, base_timestamp = 0)
      # format of sync_str:
      # min_last_synced_at,
      # "encoded_0", diff_last_requested_at_0,
      # "encoded_1", diff_last_requested_at_1,
      # "encoded_2", diff_last_requested_at_2, ...

      sync_str = sync_str.encode('UTF-8', 'UTF-8', invalid: :replace)

      encoded_min_last_synced_at, *encoded_ranges = sync_str.split(',')
      min_last_synced_at = LZString.decompress_from_encoded_uri_component(encoded_min_last_synced_at).to_i

      grouped_encoded_ranges = encoded_ranges.inject([]) do |grouped, encoded_range|
        grouped << [] if grouped.last.nil? || grouped.last.length >= 2
        grouped.last << encoded_range
        grouped
      end

      grouped_encoded_ranges.inject({}) do |synced_at_map, (encoded_caches, encoded_diff_last_synced_at)|
        primary_keys_str = LZString.decompress_from_encoded_uri_component(encoded_caches)
        primary_keys = primary_keys_str.split(",")

        if primary_keys.first.to_i.to_s == primary_keys.first
          primary_keys.map!(&:to_i)
        else
          primary_keys = primary_keys_str.scan(/.{32}/).map do |uuid_str|
            [uuid_str[0, 8], uuid_str[8, 4], uuid_str[12, 4], uuid_str[16, 4],
             uuid_str[20, 16]].join("-")
          end
        end

        diff_last_synced_at = LZString.decompress_from_encoded_uri_component(encoded_diff_last_synced_at).to_i
        last_synced_at = min_last_synced_at + diff_last_synced_at + base_timestamp

        primary_keys.each do |key|
          synced_at_map[key] = [synced_at_map[key], last_synced_at].compact.max
        end

        synced_at_map
      end
    rescue StandardError
      # invalid sync_str, return empty map
      {}
    end


    private

    # [1,2,3,6,7,8]
    # => [1..3, 6..8]
    def convert_numbers_to_ranges(numbers)
      return [] unless numbers.length.positive?

      ranges = []
      range = nil

      numbers.each_with_index do |number, i|
        range = Range.new(
          (
            if range && number == numbers[i - 1] + 1
              range.begin
            else
              number
            end
          ),
          number,
        )

        ranges << range unless numbers[i + 1] && numbers[i + 1] == number + 1
      end

      ranges
    end

    # [1..3, 6..8]
    # => "11100111"
    def convert_ranges_to_binary_number(ranges)
      binary_number = ''

      ranges.each_with_index do |range, i|
        binary_number += '0' * (range.begin - ranges[i - 1].end - 1) if i.positive?
        binary_number += '1' * (range.end - range.begin + 1)
      end

      binary_number
    end

    # "10101"
    # => 21
    def convert_binary_number_to_decimal_number(binary_number)
      decimal_number = 0

      binary_number.length.times do |i|
        decimal_number += 2**(binary_number.length - i - 1) * binary_number[i].to_i
      end

      decimal_number
    end

    # 5
    # => F"
    def encode_decimal_number(decimal_number, output_charset = ENCODED_NUMBER_CHARS)
      return nil if !decimal_number.is_a?(Integer) || decimal_number.negative?

      encoded_number = ""
      base = output_charset.length
      quotient = decimal_number
      remainder = nil

      loop do
        remainder = quotient % base
        encoded_number = output_charset[remainder] + encoded_number
        quotient = (quotient - remainder) / base
        break if quotient.zero?
      end

      encoded_number
    end
    alias_method :encode_integer, :encode_decimal_number

    # 21
    # => "10101"
    def convert_decimal_number_to_binary_number(decimal_number)
      binary_number = ""
      base = 2
      quotient = decimal_number
      remainder = 0

      while quotient != 0
        remainder = quotient % base
        binary_number = remainder.to_s + binary_number
        quotient = (quotient - remainder) / base
      end

      binary_number
    end

    # "F"
    # => 5
    def convert_encoded_number_to_decimal_number(encoded_number)
      decimal_number = 0
      index = 0

      encoded_number.each_char do |c|
        char_index = ENCODED_NUMBER_CHARS.index(c)

        # current char not found in chars, implies corrupted encoded_caches
        raise InvalidEncodedCharException if char_index.nil?

        decimal_number += ENCODED_NUMBER_CHARS.length**(encoded_number.length - index - 1) * char_index
        index += 1
      end

      decimal_number
    end
    alias_method :decode_integer, :convert_encoded_number_to_decimal_number

    # encoded_string_prefix, encoded_number, start_id
    # => [ids_to_include, end_id]
    #
    # "_", "E", 1
    # => [[], 4]
    #
    # "~", "C", 5
    # => [[5, 6], 6]
    #
    # "_", "O", 7
    # => [[], 20]
    #
    # ".", "V", 21
    # => [[21, 23, 25], 25]
    def convert_encoded_number_to_ids(encoded_string_prefix, encoded_number, start_id)
      ids = []

      case encoded_string_prefix
      when SPACES_PREFIX
        decimal_number = convert_encoded_number_to_decimal_number(encoded_number)
        end_id = start_id + decimal_number - 1
      when BINARY_PREFIX
        decimal_number = convert_encoded_number_to_decimal_number(encoded_number)
        binary_number = convert_decimal_number_to_binary_number(decimal_number)
        id = start_id
        binary_number.each_char do |c|
          if c == '1'
            ids << id
          end
          id = id + 1
        end
        end_id = id - 1
      when RANGE_PREFIX
        decimal_number = convert_encoded_number_to_decimal_number(encoded_number)
        (start_id..(start_id + decimal_number - 1)).each do |id|
          ids << id
        end
        end_id = start_id + decimal_number - 1
      end

      [ids, end_id]
    end

  end

end
