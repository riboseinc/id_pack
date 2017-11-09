require 'spec_helper'

RSpec.describe IdPack::IdPacker do

  let(:packer) do
    described_class.new
  end

  it 'should convert numbers to ranges' do
    expect(packer.send(:convert_numbers_to_ranges, [1, 2, 3, 6, 7, 8])).to eql([1..3, 6..8])
  end

  it 'should convert ranges to binary_number' do
    expect(packer.send(:convert_ranges_to_binary_number, [1..3, 6..8])).to eql("11100111")
  end

  it 'should convert binary number to decimal number' do
    expect(packer.send(:convert_binary_number_to_decimal_number, "10101")).to eql(21)
  end

  it 'should encode decimal number' do
    expect(packer.send(:encode_decimal_number, 5)).to eql("F")
  end

  it 'should convert decimal number to binary number' do
    expect(packer.send(:convert_decimal_number_to_binary_number, 10)).to eql("1010")
  end

  it 'should convert encoded number to decimal number' do
    expect(packer.send(:convert_encoded_number_to_decimal_number, "ABC")).to eql(65)
  end

  it 'should convert spaces encoded_number to ids' do
    expect(packer.send(:convert_encoded_number_to_ids, "_", "E", 1)).to eql([[], 4])
  end

  it 'should convert range encoded_number to ids' do
    expect(packer.send(:convert_encoded_number_to_ids, "~", "C", 5)).to eql([[5, 6], 6])
  end

  it 'should convert binary encoded_number to ids' do
    expect(packer.send(:convert_encoded_number_to_ids, ".", "V", 21)).to eql([[21, 23, 25], 25])
  end

  it "should decode encoded array" do
    arr = [5, 6, 21, 23, 25]
    encoded_arr = packer.encode(arr)
    expect(packer.decode(encoded_arr)).to eq(arr)
  end

  it 'should decode encoded zero array properly' do
    zero_arr = [0]
    encoded_zero_arr = packer.encode(zero_arr)
    expect(packer.decode(encoded_zero_arr)).to eq(zero_arr)
  end

  it 'should decode encoded timestamp array' do
    timestamp_arr = [(Time.now.to_f * 1000).to_i]
    encoded_timestamp_arr = packer.encode(timestamp_arr)
    expect(packer.decode(encoded_timestamp_arr)).to eq(timestamp_arr)
  end

  it "should decode encoded integers" do
    ints = [0, 1, 24 * 60 * 60, 365 * 24 * 60 * 60, (Time.now.to_f * 1000).to_i]

    ints.each do |n|
      encoded_int = packer.send(:encode_integer, n)
      expect(packer.send(:decode_integer, encoded_int)).to eq(n)
    end
  end

  it 'should encode integer arrays without any error' do
    expect {
      10.times do |i|
        int_arr = [10 ** i]
        packer.encode(int_arr)
      end
    }.to_not raise_error
  end

  it 'should decode encoded sync_str without base timestamp' do
    current_timestamp = (Time.now.to_f * 1000).to_i
    synced_at_map = {
      1 => current_timestamp,
      2 => current_timestamp,
      10 => current_timestamp,
      20 => current_timestamp - 3600000,
      23 => current_timestamp - 3600000,
      31 => current_timestamp - 1080000
    }

    sync_str = packer.encode_sync_str(synced_at_map)
    expect(packer.decode_sync_str(sync_str)).to eq(synced_at_map)
  end

  it 'should decode encoded sync_str with base timestamp' do
    current_timestamp = (Time.now.to_f * 1000).to_i
    base_timestamp = current_timestamp - 7 * 24 * 60 * 60 * 1000
    synced_at_map = {
      1 => current_timestamp,
      2 => current_timestamp,
      10 => current_timestamp,
      20 => current_timestamp - 3600000,
      23 => current_timestamp - 3600000,
      31 => current_timestamp - 1080000
    }
    synced_at_map_with_base_timestamp = synced_at_map.keys.reduce({}) do |m, k|
      m[k] = synced_at_map[k] - base_timestamp
      m
    end

    sync_str = packer.encode_sync_str(synced_at_map_with_base_timestamp)
    expect(packer.decode_sync_str(sync_str, base_timestamp)).to eq(synced_at_map)
  end

end
