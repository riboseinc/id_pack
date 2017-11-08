require "spec_helper"

RSpec.describe UuidPack do

  let(:packer) do
    Class.new do
      include UuidPack
    end.new
  end

  shared_examples_for 'uuid' do

    let(:input_length) do
      uuid_array.join.length
    end

    # Set input array
    let(:uuid_array) do
      [
        '3e514775-bfdb-44f9-92b2-c4c53a7dc89d',
        '22347af1-7c60-48e0-8cc5-a30746812267',
        'ea8bed36-a73d-4fff-af36-32162274dfd1',
      ]
    end

    # Boolean - `true` if we need to keep items ordered
    let(:ordered) { false }

    let(:compressed_array) do
      packer.alphanum_compress(uuid_array, encoding_base_string, ordered)
    end

    let(:compression_rate) do
      (1 - Rational(compressed_array.length, input_length))
    end

    it 'compresses using only characters from the base' do
      compressed_base_set = Set.new(compressed_array.split(''))
      original_base_set   = Set.new(encoding_base_string.split(''))
      compressed_diff     = compressed_base_set - original_base_set
      expect(compressed_diff).to be_empty
    end

    let(:alp_array) do
      packer.alphanum_to_array(encoding_base_string, false)
    end

    # Boolean - Check if 'delta' is being used or not
    let(:delta) do
      0 !=      alp_array.rassoc(compressed_array[0])[0] &
           (2**(alp_array.rassoc(compressed_array[0])[2] - 1))
    end

    it 'has an appropriate compression rate' do
      # XXX: 14 chars: How to derive this number?
      if encoding_base_string.length >= 14
        expect(compression_rate).to be > 0
      else
        expect(compression_rate).to be < 0
      end
    end

    let(:new_uuid_array) do
      packer.alphanum_decompress(compressed_array, encoding_base_string)
    end

    it 'decompresses without errors' do
      new_uuid_array
    end

    let(:c_uuid_array) do
      delta ? uuid_array.sort : uuid_array
    end

    it 'passes decompression checks' do
      expect(new_uuid_array).to eq c_uuid_array
    end

  end

  # 'encoding_base_string' - String.  The last character will be the delimiter
  # with delta compression.
  #
  # This equals Base64 with delimiter '_'.
  context 'with the default set of base characters' do
    let(:encoding_base_string) do
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-_'
    end
    it_behaves_like 'uuid'
  end

  lotsa_chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-_:/\\`~!@\#$%^&*()=[]{}|;'\",.<>?"
    .split('')
    .uniq

  # Progressively increase the number of characters for the base string for our
  # test cases, starting from just 2 characters.
  (2..lotsa_chars.length).each do |i|
    base = lotsa_chars.take(i).join

    context "with a base character set of #{base.length} characters" do
      let(:encoding_base_string) do
        base
      end

      it_behaves_like 'uuid'
    end
  end

end
