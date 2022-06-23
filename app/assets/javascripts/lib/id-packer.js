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
    window.IdPacker = factory();
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

    range: function(start, length) {

      /** convert arguments to numbers */
      if (typeof start != 'number') {
        start     = parseInt(start, 10);
      }
      if (typeof length != 'number') {
        length    = parseInt(length, 10);
      }
      this.start  = !$.isNumeric(start)  ? 0 : start;
      this.length = !$.isNumeric(length) ? 0 : length;

      // range functions

      /**
       * var range = IdPacker.range(0, 5);
       * range.clone();
       * => IdPacker.range(0, 5)
       */
      this.clone = function() {
        return IdPacker.range(this.start, this.length);
      };

      /**
       * var range = IdPacker.range(0, 5);
       * range.end();
       * => 4
       */
      this.end = function() {
        return this.start + this.length - 1;
      };

      /**
       * var range = IdPacker.range(3, 5);
       * range.roundToWindow(5);
       * => IdPacker.range(0, 10)
       *
       * range.roundToWindow(2);
       * => IdPacker.range(2, 6)
       */
      this.roundToWindow = function(window_size) {
        var start  = Math.floor(this.start / window_size) * window_size;
        var length = Math.ceil((this.start + this.length - start) / window_size) * window_size;
        return IdPacker.range(start, length);
      };

      /**
       * var range = IdPacker.range(0, 5);
       * range.contain(3);
       * => true
       *
       * range.contain(8);
       * => false
       */
      this.contain = function(n) {
        return n >= this.start && n <= this.end();
      };

      // range-to-range functions

      /**
       * var range1 = IdPacker.range(0, 2);
       * var range2 = IdPacker.range(2, 2);
       * var range3 = IdPacker.range(3, 2);
       * range1.touch(range2);
       * => true
       *
       * range1.touch(range3);
       * => false
       *
       * range2.touch(range3);
       * => true
       */
      this.touch = function(range) {
        var start  = Math.max(this.start, range.start);
        var end    = Math.min(this.end(), range.end());
        var length = end - start + 1;
        return length >= 0;
      };

      /**
       * var range1 = IdPacker.range(2, 2);
       * var range2 = IdPacker.range(3, 2);
       * range1.intersect(range2);
       * => IdPacker.range(3, 1)
       */
      this.intersect = function(range) {
        var start  = Math.max(this.start, range.start);
        var end    = Math.min(this.end(), range.end());
        var length = end - start + 1;
        return (length > 0) ? IdPacker.range(start, length) : null;
      };

      /**
       * var range1 = IdPacker.range(2, 2);
       * var range2 = IdPacker.range(2, 5);
       * var range3 = IdPacker.range(0, 5);
       * range1.isSubsetOf(range3);
       * => true
       *
       * range2.isSubsetOf(range3);
       * => false
       */
      this.isSubsetOf = function(range) {
        return range.contain(this.start) && range.contain(this.end());
      };

      /**
       * var range1 = IdPacker.range(0, 5);
       * var range2 = IdPacker.range(2, 5);
       * range1.union(range2);
       * => IdPacker.range(0, 7)
       */
      this.union = function(range) {
        var start = Math.min(this.start, range.start);
        var end = Math.max(this.end(), range.end());
        var length = end - start + 1;
        return IdPacker.range(start, length);
      };

      /**
       * var range1 = IdPacker.range(0, 5);
       * var range2 = IdPacker.range(2, 5);
       * range1.minus(range2);
       * => IdPacker.range(0, 2)
       */
      this.minus = function(range) {
        var intersectedRange = this.intersect(range);
        if (this.equal(intersectedRange)) {
          return [];
        } else if (this.start < intersectedRange.start && this.end() > intersectedRange.end()) {
          return [(IdPacker.range(this.start, intersectedRange.start - this.start)),
            (IdPacker.range(intersectedRange.end() + 1, this.end() - intersectedRange.end()))];
        } else if (this.start < intersectedRange.start) {
          return [IdPacker.range(this.start, intersectedRange.start - this.start)];
        } else {
          return [IdPacker.range(intersectedRange.end() + 1, this.end() - intersectedRange.end())];
        }
      };

      /**
       * var range1 = IdPacker.range(0, 2);
       * var range2 = IdPacker.range(0, 2);
       * var range3 = IdPacker.range(2, 2);
       * range1.equal(range2);
       * => true
       *
       * range1.equal(range3);
       * => false
       */
      this.equal = function (range) {
        return this.start == range.start && this.length == range.length;
      };

      // range-to-ranges functions

      /**
       * var range1 = IdPacker.range(0, 2);
       * var range2 = IdPacker.range(2, 2);
       * var ranges = [IdPacker.range(0, 3), IdPacker.range(5, 3)];
       * range1.hasFullRange(ranges);
       * => true
       *
       * range2.hasFullRange(ranges);
       * => false
       */
      this.hasFullRange = function(ranges) {
        for(var i = 0, l = ranges.length; i < l; i++) {
          if (this.isSubsetOf(ranges[i])) {
            return true;
          }
        }
        return false;
      };

      /**
       * var range = IdPacker.range(2, 5);
       * var ranges = [IdPacker.range(0, 3), IdPacker.range(5, 3)];
       * range.getOverlapRanges(ranges);
       * => [IdPacker.range(2, 1), IdPacker.range(5, 2)]
       */
      this.getOverlapRanges = function(ranges) {
        var overlapRanges = [];
        for(var i = 0, l = ranges.length; i < l; i++) {
          var intersectedRange = this.intersect(ranges[i]);
          if (intersectedRange !== null) {
            overlapRanges.push(intersectedRange);
          }
        }
        return overlapRanges;
      };

      /**
       * var range = IdPacker.range(2, 5);
       * var ranges = [IdPacker.range(0, 3), IdPacker.range(5, 3)];
       * range.getMissingRanges(ranges);
       * => [IdPacker.range(3, 2)]
       */
      this.getMissingRanges = function(ranges) {
        var overlapRanges = this.getOverlapRanges(ranges);
        var missingRanges = [];
        var missingRange  = this;

        for(var i = 0, ol = overlapRanges.length; i < ol; i++) {
          var currentMissingRanges = missingRange.minus(overlapRanges[i]);
          for (var j = 0, cl = currentMissingRanges.length-1; j < cl; j++) {
            missingRanges.push(currentMissingRanges[j]);
          }
          missingRange = currentMissingRanges[currentMissingRanges.length-1];
        }

        if (missingRange) {
          missingRanges.push(missingRange);
        }
        return missingRanges;
      };

      /**
       * var range = IdPacker.range(2, 5);
       * var ranges = [IdPacker.range(0, 3), IdPacker.range(5, 3)];
       * range.addToRanges(ranges);
       * => [IdPacker.range(0, 8)]
       */
      this.addToRanges = function(ranges){
        if (! ranges.length) {
          ranges.push(this);
          return ranges;
        }
        var i, l;
        var overlapRanges = [];
        var accumulate;

        for (i = 0, l = ranges.length; i < l; i++) {
          if (this.touch(ranges[i])) {
            overlapRanges.push(i);
          }
        }
        if (overlapRanges.length === 0) {
          for (i = 0, l = ranges.length; i < l; i++) {
            if (this.start < ranges[i].start) {
              Array.prototype.splice.apply(ranges, [i, 0].concat(this));
              return ranges;
            }
          }
          ranges.push(this);
          return ranges;
        }

        accumulate = this;
        for (i = 0, l = overlapRanges.length; i < l; i++) {
          accumulate = accumulate.union(ranges[overlapRanges[i]]);
        }

        Array.prototype.splice.apply(
          ranges, [overlapRanges[0], overlapRanges.length].concat(accumulate)
        );
        return ranges;
      };

      /**
       * var range = IdPacker.range(2, 5);
       * var ranges = [IdPacker.range(0, 3), IdPacker.range(5, 3)];
       * range.deleteFromRanges(ranges);
       * => [IdPacker.range(0, 2), IdPacker.range(7, 1)]
       *
       * @param {Array(Range)} ranges
       * @return {Array(Range)}
       */
      this.deleteFromRanges = function(ranges) {
        var i, l;
        var overlapRanges = [];
        var accumulate    = [];

        for (i = 0, l = ranges.length; i < l; i++) {
          if (this.intersect(ranges[i]) !== null) {
            overlapRanges.push(i);
          }
        }
        if (overlapRanges.length === 0) {
          return ranges;
        }

        accumulate = [];

        for (i = 0, l = overlapRanges.length; i < l; i++) {
          accumulate = accumulate.concat(ranges[overlapRanges[i]].minus(this));
        }

        Array.prototype.splice.apply(
          ranges, [overlapRanges[0], overlapRanges.length].concat(accumulate)
        );
        return ranges;
      };
    },

    /**
     * [1,2,3,6,7,8]
     * => [IdPacker.range(start: 1 length: 3), IdPacker.range(start: 6 length: 3)]
     */
    convertNumbersToRanges: function (numbers) {
      var ranges = [];
      if (numbers.length > 0) {
        var range = IdPacker.range(numbers[0], 1);
        for (var i = 1; i < numbers.length; i++) {
          if (numbers[i] == numbers[i-1]+1) {
            range.length = range.length + 1;
          } else {
            ranges.push(range);
            range = IdPacker.range(numbers[i], 1);
          }
        }
        ranges.push(range);
      }
      return ranges;
    },

    /**
     * [IdPacker.range(start: 1 length: 3), IdPacker.range(start: 6 length: 3)]
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
