/** vim: et:ts=2:sw=2:sts=2
 * @license (c) 2017 Ribose Inc.
 *
 * IdPacker is a library provides encoding support for Number collections (Arrays or Objects).
 *
 *
 * Usage:
 *
 * The encoding algorithm encodes a Number collection (in form of Array or Object) into another String.
 *
 * @param collection - Number collection (in form of Array or Object)
 * @param windowSize - Maximunm length of the binary encodedString in binary form (default: 10)
 * @param isExcludeNull - Exclude the object keys with null value (default: true)
 * @param outputCharset - Control how the output look like. CANNOT CONTAIN DUPLICATED characters (default: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-")
 *
 * IdPacker.encodeHashKeys(collection, windowSize, isExcludeNull, outputCharset);
 *
 *
 * Examples:
 *
 * // encode the items in an Array
 * var collection = [5, 6, 21, 23, 25];
 * IdPacker.encodeHashKeys(collection);
 * => "_E~C_O.V"
 *
 * // encode the keys of an Object
 * var collection = {
 *   5: "a",
 *   6: "b",
 *   21: "c",
 *   23: "d",
 *   25: "e"
 * };
 * IdPacker.encodeHashKeys(collection);
 * => "_E~C_O.V"
 *
 *
 * The encoding algorithm:
 *
 * The algorithm first sorts the collection in ascending order. Then, it decomposes
 * the sorted collection into multiple parts starting from 1. Finally, each part is
 * encoded into one of the following three encodedString forms:
 *
 * 1) Spaces encodedString
 * A encoded text with prefix '_', represents continuous space.
 *
 * 2) Range encodedString
 * A encoded text with prefix '~', represents continuous number.
 *
 * 3) Binary encodedString
 * A encoded text with prefix '.', represents arbitrary distributed numbers.
 *
 * In each part, the encodedString after the prefix is a value from a base-X number system, where
 * X is the length of IdPacker.outputCharset (overridable).
 *
 * Take the encoded text "_E~C_O.V" (original collection: [5, 6, 21, 23, 25]) as an example.
 * It consists of 4 parts：
 *
 * 1）_E
 * 4 continuous space (0-4)
 *
 * 2) ~C
 * 2 continuous number (5,6)
 *
 * 3) _O
 * 14 continuous space (7-20)
 *
 * 4) .V
 * Convert 'V' from the base-X number system to base-10 number system gives '21',
 * convert '21' from the base-10 number system to base-2 (binary) number system gives '101'.
 * '1' and '0' represent 'number' and 'space', respectively. Therefore, '101' denotes 21, 23, 25.
 */
(function (factory) {
  'use strict';

  /* AMD. Register as an anonymous module. */
  if (typeof define === 'function' && define.amd) {
    define(factory);
  }

  /* Node/CommonJS */
  else if (typeof exports === 'object') {
    module.exports = factory();
  }

  /* Browser globals */
  else {
    factory();
  }

}(function() {
  'use strict';

  return {
    spacesEncodedStringPrefix: '_',
    binaryEncodedStringPrefix: '.',
    rangeEncodedStringPrefix:  '~',
    windowSize:                10,
    isExcludeNull:             true,
    outputCharset:             "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-",

    /**
     * [1,2,3,6,7,8]
     * => [IdPack.range(start: 1 length: 3), IdPack.range(start: 6 length: 3)]
     */
    convertNumbersToRanges: function (numbers) {
      var ranges = [];
      if (numbers.length > 0) {
        var range = new IdPack.range(numbers[0], 1);
        for (var i = 1; i < numbers.length; i++) {
          if (numbers[i] == numbers[i-1]+1) {
            range.length = range.length + 1;
          } else {
            ranges.push(range);
            range = new IdPack.range(numbers[i], 1);
          }
        }
        ranges.push(range);
      }
      return ranges;
    },

    /**
     * [IdPack.range(start: 1 length: 3), IdPack.range(start: 6 length: 3)]
     * => "11100111"
     */
    convertRangesToBinaryNumber: function (ranges) {
      var binaryNumber = '';
      var i, j;
      for (i = 0; i < ranges.length; i++) {
        if (i > 0) {
          for (j = ranges[i].start; j > ranges[i-1].end() + 1; j--) {
            binaryNumber += '0';
          }
        }
        for (j = 0; j < ranges[i].length; j++) {
          binaryNumber += '1';
        }
      }
      return binaryNumber;
    },

    /**
     * [5, 6, 21, 23, 25]
     * => "_E~C_O.V"
     */
    encodeHashKeys: function(hash, windowSize, isExcludeNull, outputCharset) {
      // set default values
      windowSize    = typeof  windowSize   === "number"  ? windowSize    : this.windowSize;
      isExcludeNull = typeof isExcludeNull === "boolean" ? isExcludeNull : this.isExcludeNull;
      outputCharset = typeof outputCharset === "string"  ? outputCharset : this.outputCharset;

      var encodedHashKeys = '';
      var hashKeys = hash instanceof Array ? hash : [];

      // convert keys in Object into array if collection is an Object
      if (! (hash instanceof Array)) {
        var hashKey;
        for (hashKey in hash) {
          if (!isExcludeNull || isExcludeNull && hash[hashKey]) {
            hashKeys.push(parseInt(hashKey, 10));
          }
        }

        if (! hashKeys.length) {
          return '';
        }
      }

      // sort the collection in ascending order
      hashKeys.sort(function(a,b) {
        return a - b;
      });

      var ranges        = this.convertNumbersToRanges(hashKeys);
      var prevEnd       = 0;
      var currStart     = 1;
      var spaces        = 0;
      var groupWithPrev = false;
      var rangesToGroup = [];
      var binaryNumber  = '';
      var decimalNumber = 0;
      var encodedString = '';

      for (var i = 0; i < ranges.length; i++) {

        spaces = ranges[i].start - prevEnd;

        if (groupWithPrev) {

          if (ranges[i].end() - currStart + 1 == windowSize) {
            rangesToGroup.push(ranges[i]);
            binaryNumber     = this.convertRangesToBinaryNumber(rangesToGroup);
            decimalNumber    = this.convertBinaryNumberToDecimalNumber(binaryNumber);
            encodedString    = this.binaryPrefix + this.encodeDecimalNumber(decimalNumber, outputCharset);
            encodedHashKeys += encodedString;
            rangesToGroup    = [];
            groupWithPrev    = false;
          } else if (ranges[i].end() - currStart + 1 >= windowSize) {

            if (rangesToGroup.length == 1) {
              encodedString    = this.rangePrefix + this.encodeDecimalNumber(rangesToGroup[0].length, outputCharset);
              encodedHashKeys += encodedString;
            } else {
              binaryNumber     = this.convertRangesToBinaryNumber(rangesToGroup);
              decimalNumber    = this.convertBinaryNumberToDecimalNumber(binaryNumber);
              encodedString    = this.binaryPrefix + this.encodeDecimalNumber(decimalNumber, outputCharset);
              encodedHashKeys += encodedString;
            }

            rangesToGroup    = [];
            encodedString    = this.spacesPrefix + this.encodeDecimalNumber(spaces, outputCharset);
            encodedHashKeys += encodedString;

            if (ranges[i].length >= windowSize) {
              encodedString    = this.rangePrefix + this.encodeDecimalNumber(ranges[i].length, outputCharset);
              encodedHashKeys += encodedString;
              groupWithPrev    = false;
            } else {
              rangesToGroup.push(ranges[i]);
              currStart     = ranges[i].start;
              groupWithPrev = true;
            }
          } else {
            rangesToGroup.push(ranges[i]);
          }
        } else {
          if (spaces >= 0) {
            encodedString    = this.spacesPrefix + this.encodeDecimalNumber(spaces, outputCharset);
            encodedHashKeys += encodedString;
          }
          if (ranges[i].length >= windowSize) {
            encodedString    = this.rangePrefix + this.encodeDecimalNumber(ranges[i].length, outputCharset);
            encodedHashKeys += encodedString;
          } else {
            rangesToGroup.push(ranges[i]);
            currStart     = ranges[i].start;
            groupWithPrev = true;
          }
        }
        prevEnd = ranges[i].end();
      }

      if (rangesToGroup.length == 1) {
        encodedString    = this.rangePrefix + this.encodeDecimalNumber(rangesToGroup[0].length, outputCharset);
        encodedHashKeys += encodedString;
      } else if (rangesToGroup.length > 0) {
        binaryNumber     = this.convertRangesToBinaryNumber(rangesToGroup);
        decimalNumber    = this.convertBinaryNumberToDecimalNumber(binaryNumber);
        encodedString    = this.binaryPrefix + this.encodeDecimalNumber(decimalNumber, outputCharset);
        encodedHashKeys += encodedString;
      }
      return encodedHashKeys;
    },

    encodeInteger: function (n) {
      return this.encodeDecimalNumber(n);
    },

    /**
     * "10101"
     * => 21
     */
    convertBinaryNumberToDecimalNumber: function(binaryNumber) {
      var decimalNumber = 0;
      for (var i = 0; i < binaryNumber.length; i++) {
        decimalNumber = decimalNumber + Math.pow(2, binaryNumber.length - i - 1) * parseInt(binaryNumber.charAt(i), 10);
      }
      return decimalNumber;
    },

    /**
     * 5
     * => F"
     */
    encodeDecimalNumber: function(decimalNumber, outputCharset) {
      if (typeof outputCharset == 'undefined' || outputCharset == null) {
        outputCharset = this.outputCharset;
      }
      var encodedNumber = "";
      var base          = outputCharset.length;
      var quotient      = decimalNumber;
      var remainder;
      while (true) {
        remainder = quotient % base;
        encodedNumber = outputCharset.charAt(remainder) + encodedNumber;
        quotient = (quotient - remainder) / base;
        if (quotient == 0) {
          break;
        }
      }
      return encodedNumber;
    }
  };

}));
