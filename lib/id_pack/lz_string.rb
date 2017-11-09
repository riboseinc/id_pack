module IdPack
  module LZString
    KEY_STR_BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
    KEY_STR_URI_SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-$"

    class << self

      def get_base_value alphabet, character
        @base_reverse_dic ||= {}

        if !@base_reverse_dic[alphabet]
          @base_reverse_dic[alphabet] = {}

          alphabet.length.times do |i|
            @base_reverse_dic[alphabet][alphabet[i]] = i
          end
        end

        @base_reverse_dic[alphabet][character]
      end

      def compress_to_base64 input
        return "" if input.nil?

        res = _compress(input, 6) do |a|
          KEY_STR_BASE64[a]
        end

        case res.length % 4
        when 0 then res
        when 1 then res + "==="
        when 2 then res + "=="
        when 3 then res + "="
        end
      end

      def decompress_from_base64 input
        return "" if input.nil?
        return nil if input == ""

        _decompress(input.length, 32) do |index|
          get_base_value(KEY_STR_BASE64, input[index])
        end
      end

      def compress_to_utf16 input
        return "" if input.nil?

        _compress(input, 15) do |a|
          [a + 32].pack 'U'
        end + " "
      end

      def decompress_from_utf16 compressed
        return "" if compressed.nil?
        return nil if compressed == ""

        _decompress(compressed.length, 16384) do |index|
          compressed[index].ord - 32
        end
      end

      def compress_to_uint8_array uncompressed
        compressed = compress(uncompressed)
        buf = []

        compressed.length.times do |i|
          current_value = compressed[i].ord
          buf[i * 2] = current_value >> 8 # TODO: >>> 8 how to do it in ruby?
          buf[i * 2 + 1] = current_value % 256
        end

        buf
      end

      def decompress_from_uint8_array compressed
        return decompress(compressed) if compressed.nil?

        buf = []

        (compressed.length / 2).times do |i|
          buf[i] = compressed[i * 2] * 256 + compressed[i * 2 + 1]
        end

        result = []

        buf.each do |c|
          result.push(
            [a + 32].pack 'U'
          )
        end

        decompress(result.join(''))
      end

      def compress_to_encoded_uri_component input
        return "" if input.nil?

        _compress(input, 6) do |a|
          KEY_STR_URI_SAFE[a]
        end
      end

      def decompress_from_encoded_uri_component input
        return "" if input.nil?
        return nil if input == ""

        input.gsub!(/ /, "+")

        _decompress(input.length, 32) do |index|
          get_base_value(KEY_STR_URI_SAFE, input[index])
        end
      end

      def compress uncompressed
        _compress(uncompressed, 16) do |a|
          [a].pack 'U'
        end
      end

      def _compress uncompressed, bits_per_char, &get_char_from_int
        return "" if uncompressed.nil?

        context_dictionary = {}
        context_dictionary_to_create = {}
        context_c = ""
        context_wc = ""
        context_w = ""
        context_enlarge_in = 2
        context_dict_size = 3
        context_num_bits = 2
        context_data = []
        context_data_val = 0
        context_data_position = 0

        uncompressed.length.times do |ii|
          context_c = uncompressed[ii]

          if !context_dictionary[context_c]
            context_dictionary[context_c] = context_dict_size
            context_dict_size += 1
            context_dictionary_to_create[context_c] = true
          end

          context_wc = context_w + context_c

          if context_dictionary[context_wc]
            context_w = context_wc
          else
            if context_dictionary_to_create[context_w]
              if context_w[0].ord < 256
                context_num_bits.times do |i|
                  context_data_val = (context_data_val << 1)

                  if context_data_position == bits_per_char - 1
                    context_data_position = 0
                    context_data.push(get_char_from_int.call(context_data_val))
                    context_data_val = 0
                  else
                    context_data_position += 1
                  end
                end

                value = context_w[0].ord

                8.times do |i|
                  context_data_val = (context_data_val << 1) | (value & 1)

                  if context_data_position == bits_per_char - 1
                    context_data_position = 0
                    context_data.push(get_char_from_int.call(context_data_val))
                    context_data_val = 0
                  else
                    context_data_position += 1
                  end

                  value = value >> 1
                end
              else
                value = 1

                context_num_bits.times do |i|
                  context_data_val = (context_data_val << 1) | value

                  if context_data_position == bits_per_char - 1
                    context_data_position = 0
                    context_data.push(get_char_from_int.call(context_data_val))
                    context_data_val = 0
                  else
                    context_data_position += 1
                  end

                  value = 0
                end

                value = context_w[0].ord

                16.times do |i|
                  context_data_val = (context_data_val << 1) | (value & 1)

                  if context_data_position == bits_per_char - 1
                    context_data_position = 0
                    context_data.push(get_char_from_int.call(context_data_val))
                    context_data_val = 0
                  else
                    context_data_position += 1
                  end

                  value = value >> 1
                end
              end

              context_enlarge_in -= 1

              if context_enlarge_in == 0
                context_enlarge_in = 2 ** context_num_bits
                context_num_bits += 1
              end

              context_dictionary_to_create.delete(context_w)
            else
              value = context_dictionary[context_w]

              context_num_bits.times do |i|
                context_data_val = (context_data_val << 1) | (value & 1)

                if context_data_position == bits_per_char - 1
                  context_data_position = 0
                  context_data.push(get_char_from_int.call(context_data_val))
                  context_data_val = 0
                else
                  context_data_position += 1
                end

                value = value >> 1
              end
            end

            context_enlarge_in -= 1

            if context_enlarge_in == 0
              context_enlarge_in = 2 ** context_num_bits
              context_num_bits += 1
            end

            context_dictionary[context_wc] = context_dict_size
            context_dict_size += 1
            context_w = context_c.to_s
          end
        end

        if context_w != ""
          if context_dictionary_to_create[context_w]
            if context_w[0].ord < 256
              context_num_bits.times do |i|
                context_data_val = context_data_val << 1

                if context_data_position == bits_per_char - 1
                  context_data_position = 0
                  context_data.push(get_char_from_int.call(context_data_val))
                  context_data_val = 0
                else
                  context_data_position += 1
                end
              end

              value = context_w[0].ord

              8.times do |i|
                context_data_val = (context_data_val << 1) | (value & 1)

                if context_data_position == bits_per_char - 1
                  context_data_position = 0
                  context_data.push(get_char_from_int.call(context_data_val))
                  context_data_val = 0
                else
                  context_data_position += 1
                end

                value = value >> 1
              end
            else
              value = 1

              context_num_bits.times do |i|
                context_data_val = (context_data_val << 1) | value

                if context_data_position == bits_per_char - 1
                  context_data_position = 0
                  context_data.push(get_char_from_int.call(context_data_val))
                  context_data_val = 0
                else
                  context_data_position += 1
                end

                value = 0
              end

              value = context_w[0].ord

              16.times do |i|
                context_data_val = (context_data_val << 1) | (value & 1)

                if context_data_position == bits_per_char - 1
                  context_data_position = 0
                  context_data.push(get_char_from_int.call(context_data_val))
                  context_data_val = 0
                else
                  context_data_position += 1
                end

                value = value >> 1
              end
            end

            context_enlarge_in -= 1

            if context_enlarge_in == 0
              context_enlarge_in = 2 ** context_num_bits
              context_num_bits += 1
            end

            context_dictionary_to_create.delete(context_w)
          else
            value = context_dictionary[context_w]

            context_num_bits.times do |i|
              context_data_val = (context_data_val << 1) | (value & 1)

              if context_data_position == bits_per_char - 1
                context_data_position = 0
                context_data.push(get_char_from_int.call(context_data_val))
                context_data_val = 0
              else
                context_data_position += 1
              end

              value = value >> 1
            end
          end

          context_enlarge_in -= 1

          if context_enlarge_in == 0
            context_enlarge_in = 2 ** context_num_bits
            context_num_bits += 1
          end
        end

        value = 2

        context_num_bits.times do |i|
          context_data_val = (context_data_val << 1) | (value & 1)

          if context_data_position == bits_per_char - 1
            context_data_position = 0
            context_data.push(get_char_from_int.call(context_data_val))
            context_data_val = 0
          else
            context_data_position += 1
          end

          value = value >> 1
        end

        while true do
          context_data_val = (context_data_val << 1)

          if context_data_position == bits_per_char - 1
            context_data.push(get_char_from_int.call(context_data_val))
            break
          else
            context_data_position += 1
          end
        end

        context_data.join('')
      end

      def decompress compressed
        return "" if compressed.nil?
        return null if compressed == ""

        _decompress(compressed.length, 32768) do |index|
          compressed[index].ord
        end
      end

      def _decompress length, reset_value, &get_next_value
        dictionary = []
        enlarge_in = 4
        dict_size = 4
        num_bits = 3
        entry = ""
        result = []
        data = {
          val: get_next_value.call(0),
          position: reset_value,
          index: 1
        }

        3.times do |i|
          dictionary[i] = i
        end

        bits = 0
        maxpower = 2 ** 2
        power = 1

        while power != maxpower
          resb = data[:val] & data[:position]
          data[:position] = data[:position] >> 1

          if data[:position] == 0
            data[:position] = reset_value
            data[:val] = get_next_value.call(data[:index])
            data[:index] += 1
          end

          bits |= (resb > 0 ? 1 : 0) * power
          power = power << 1
        end

        case bits
        when 0
          bits = 0
          maxpower = 2 ** 8
          power = 1

          while power != maxpower
            resb = data[:val] & data[:position]
            data[:position] = data[:position] >> 1

            if data[:position] == 0
              data[:position] = reset_value
              data[:val] = get_next_value.call(data[:index])
              data[:index] += 1
            end

            bits |= (resb > 0 ? 1 : 0) * power
            power <<= 1
          end

          c = [bits].pack 'U'
        when 1
          bits = 0
          maxpower = 2 ** 16
          power = 1

          while power != maxpower
            resb = data[:val] & data[:position]
            data[:position] = data[:position] >> 1

            if data[:position] == 0
              data[:position] = reset_value
              data[:val] = get_next_value.call(data[:index])
              data[:index] += 1
            end

            bits |= (resb > 0 ? 1 : 0) * power
            power <<= 1
          end

          c = [bits].pack 'U'
        when 2
          return ""
        end

        dictionary[3] = c
        w = c
        result.push(c)

        while true do
          return "" if data[:index] > length

          bits = 0
          maxpower = 2 ** num_bits
          power = 1

          while power != maxpower
            resb = data[:val] & data[:position]
            data[:position] = data[:position] >> 1

            if data[:position] == 0
              data[:position] = reset_value
              data[:val] = get_next_value.call(data[:index])
              data[:index] += 1
            end

            bits |= (resb > 0 ? 1 : 0) * power
            power <<= 1
          end

          c = bits

          case bits
          when 0
            bits = 0
            maxpower = 2 ** 8
            power = 1

            while power != maxpower
              resb = data[:val] & data[:position]
              data[:position] >>= 1

              if data[:position] == 0
                data[:position] = reset_value
                data[:val] = get_next_value.call(data[:index])
                data[:index] += 1
              end

              bits |= (resb > 0 ? 1 : 0) * power
              power <<= 1
            end

            dictionary[dict_size] = [bits].pack 'U'
            dict_size += 1
            c = dict_size - 1
            enlarge_in -= 1
          when 1
            bits = 0
            maxpower = 2 ** 16
            power = 1

            while power != maxpower
              resb = data[:val] & data[:position]
              data[:position] >>= 1

              if data[:position] == 0
                data[:position] = reset_value
                data[:val] = get_next_value.call(data[:index])
                data[:index] += 1
              end

              bits |= (resb > 0 ? 1 : 0) * power
              power <<= 1
            end

            dictionary[dict_size] = [bits].pack 'U'
            dict_size += 1
            c = dict_size - 1
            enlarge_in -= 1
          when 2
            return result.join("")
          end

          if enlarge_in == 0
            enlarge_in = 2 ** num_bits
            num_bits += 1
          end

          if dictionary[c]
            entry = dictionary[c]
          else
            return nil if c != dict_size

            entry = w + w[0]
          end

          result.push(entry)

          dictionary[dict_size] = w + entry[0]
          dict_size += 1
          enlarge_in -= 1

          w = entry

          if enlarge_in == 0
            enlarge_in = 2 ** num_bits
            num_bits += 1
          end
        end
      end

    end

  end

end
