require "spec_helper"

RSpec.describe UuidPack do
  it "has a version number" do
    expect(UuidPack::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end

# TODO: convert the test below into RSpec tests.
__END__
include UuidPack
# Set valid characters (last one will be delimiter with delta compression)
# this equal Base64 with delimiter '_'
alpStrBase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-_'

# this equal binary
code = 0
alpStrBin = ''
while code < 256
  alpStrBin += (code).chr
  code += 1
end

# this demonstrate a possibility of a very small number of valid characters
alpStrBit = '01'
alpStr = alpStrBase

puts 'Valid characters:' + alpStr

# Set input array
uUIDArray = [
  '3e514775-bfdb-44f9-92b2-c4c53a7dc89d',
  '22347af1-7c60-48e0-8cc5-a30746812267',
  'ea8bed36-a73d-4fff-af36-32162274dfd1'
]

puts 'Input array:' + uUIDArray.to_s
puts 'Input length (without quotes and spaces) is: ' + uUIDArray.to_s.gsub('"', '').gsub(' ', '').length.to_s

# Set order (true if we need to keep order)
order = false

# Make compress
compressArr = alphanum_compress uUIDArray, alpStr, order
puts 'Output:' + compressArr
puts 'Output length is: ' + compressArr.length.to_s
puts 'Efficiency of compression is: ' +
  sprintf('%0.2f', (1.0 - compressArr.length.to_f / uUIDArray.to_s.gsub('"', '').gsub(' ', '').length.to_f) * 100) + '% length decrease'

# Check did delta used or not
alpArr = alphanum_to_array alpStr, false
delta = alpArr.rassoc(compressArr[0])[0] & (2 ** (alpArr.rassoc(compressArr[0])[2] - 1)) != 0
puts 'Delta used:' + delta.to_s

# Make decompress
nEWuUIDArray = alphanum_decompress compressArr, alpStr
puts 'Decompressed array:' + nEWuUIDArray.to_s

# Decompression check
cuUIDArray = uUIDArray
cuUIDArray = uUIDArray.sort if delta
if cuUIDArray == nEWuUIDArray then puts 'Decompression is successful' else puts 'Decompression error!!!' end
