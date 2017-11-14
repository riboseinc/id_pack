/** vim: et:ts=2:sw=2:sts=2
 * @license (c) 2017 Ribose Inc.
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
    window.UuidPacker = factory();
  }

}(function() {
  'use strict';

  var UNIT_LEN = 32; // a constant = length of each of the archived strings, for UUID is 32, in other cases it can vary

  return {

    // calculate bits in number
    binPow: function(num) {
      var pow = 0;
      while (num >> pow !== 0) { pow += 1; }
      return pow;
    },

    // calculate bits in the string that is hexadecimal number
    strPow: function (str) {
      return binPow(parseInt(str, 16));
    },

    // instead Ruby string reverse
    revString: function (str) {
      var
      splitString  = str.split(""),
      reverseArray = splitString.reverse(),
      joinArray    = reverseArray.join("");

      return joinArray;
    },

    // instead Ruby assoc
    assoc: function(arr, value) {
      var i;
      for (i = 0; i < arr.length; i += 1) {
        if (arr[i][0] === value) { return arr[i][1]; }
      }
    },

    // instead Ruby rassoc
    rassoc: function(arr, value) {
      var i;
      for (i = 0; i < arr.length; i += 1) {
        if (arr[i][1] === value) { return arr[i][0]; }
      }
    },

    tassoc: function(arr, value) {
      var i;
      for (i = 0; i < arr.length; i += 1) {
        if (arr[i][1] === value) { return arr[i][2]; }
      }
    },

    // 3 functions instead Ruby actions with big integer (128 bits)
    // addition
    addHexStr: function(fnum, snum) {
      var
      delta  = 0,
      result = '',
      i, sum;

      for (i = fnum.length - 1; i >= 0; i -= 1) {
        sum   = parseInt(fnum.charAt(i), 16) + parseInt(snum.charAt(i), 16) + delta;
        delta = 0;

        if (sum > 15) {
          delta  = 1;
          sum   -= 16;
        }
        result = (sum).toString(16) + result;
      }
      return result;
    },

    // subtraction
    subHexStr: function(fnum, snum) {
      var
      delta  = 0,
      result = '',
      i, sum;

      for (i = fnum.length - 1; i >= 0; i -= 1) {
        sum   = parseInt(fnum.charAt(i), 16) - parseInt(snum.charAt(i), 16) - delta;
        delta = 0;

        if (sum < 0) {
          delta  = 1;
          sum   += 16;
        }
        result = (sum).toString(16) + result;
      }
      return result;
    },

    // removing the leading zeros
    cutHexStr: function(str) {
      var i;
      for (i = 0; i < str.length; i += 1) {
        if (str.charAt(i) !== '0') {break; }
      }
      return str.substr(i, str.length - i);
    },

    //transform string of valid characters to useful array (del = true if we need delimiter)
    alptoArr: function(alpStr, del) {
      var
      alpArr = [],
      el     = alpStr.length,
      charItem,
      pow    = binPow(el - 1), // max number of bits coding by one character (some characters will be one bit less)
      lowhi  = (1 << pow) - el; // how many characters will be one bit less

      if (del) { // if delimited we can't use last characters so recalculate variables
        el    -= 1;
        pow    = binPow(el - 1);
        lowhi  = (1 << pow) - el;
        if (lowhi === 0) { lowhi -= 1; }
        alpArr[alpArr.length] = [lowhi, alpStr.charAt(el), pow]; // first element include main data about alphabet and delimiter character
        if (lowhi === -1) { lowhi += 1; }
      } else {
        if (lowhi === 0) { lowhi -= 1; }
        alpArr[alpArr.length] = [lowhi, '', pow]; // first element include main data about alphabet
        if (lowhi === -1) { lowhi += 1; }
      }

      for (charItem = 0; charItem < el; charItem += 1) { // loop by characters and get code and bit number for each one
        if (charItem < lowhi) {
          alpArr[alpArr.length] = [charItem, alpStr.charAt(charItem), pow - 1];
        } else {
          alpArr[alpArr.length] = [lowhi + charItem, alpStr.charAt(charItem), pow];
        }
      }
      return alpArr;
    },

    // compress UUIDs array
    alpCompress: function(arr, alpStr, order) {
      // declare starting values
      var
      alpArr  = alptoArr(alpStr, false), // get alphabet array without delimiter
      nresult = '', // without delta we starting with only one bit
      dresult = alpArr[alpArr.length - 1][1], // with delta we starting with delimiter (last character in alphabet, always has code of all ones)
      prev    = ('0').repeat(UNIT_LEN), // previous UUID for compress with delta (at start is zero)
      next, // next UUID for compress with delta
      pow     = alpArr[0][2],
      lowhi   = alpArr[0][0],
      achr    = 0, // first bit equal 0 means we compress without delta
      rest    = 1,
      item, // current UUID
      i, // counters for loop
      j,
      curr, // buffer for bits of current character
      powC, // number of bits of current character
      code; // the code of current compressed symbol

      // compress without delta
      for (i = 0; i < arr.length; i += 1) { // loop by UUIDs

        item = arr[i].replace(new RegExp('-', 'g'), ''); // remove '-' characters from UUID

        for (j = item.length - 1; j >= 0; j -= 1) { // loops by UUID characters

          curr  = parseInt(item.charAt(j), 16); // get base binary code (BBC)
          achr += (curr << rest);
          rest += 4; // add BBC length

          while (rest >= pow) { // create symbols to compressed string
            powC = pow - 1; // try with a short symbol length
            code = parseInt(revString(((achr & ((1 << powC) - 1)) + (1 << powC)).toString(2)), 2) >> 1;

            if (code >= lowhi) {powC += 1; } // if we get code of long length symbols

            rest     -= powC; // decrease BBC length
            code      = parseInt(revString(((achr & ((1 << powC) - 1)) + (1 << powC)).toString(2)), 2) >> 1; // get reverse bits from the end of BBC to create new symbol
            nresult  += assoc(alpArr, code); // add new symbol
            achr    >>= powC; // remove used bits from BBC
          }
        }
      }

      if (rest > 0) { // check if we have tail of BBC
        code   = parseInt(revString(((achr & ((1 << rest) - 1)) + (1 << rest)).toString(2)), 2) >> 1; // get reverse bits of BBC to create new symbol
        code <<= (pow - rest - 1); // add zeros to get valid symbol code

        if (code >= lowhi) { code <<= 1; } // if we get code of long length symbols

        nresult += assoc(alpArr, code); // add tail symbol
      }
      // compress with delta
      arr.sort();
      alpArr = alptoArr(alpStr, true); // get alphabet array with delimiter
      pow    = alpArr[0][2];

      if ((pow > 1) && (!order)) { // we can't operate single symbol alphabet and not need to calculate delta if we keep order 

        lowhi = alpArr[0][0];

        for (i = 0; i < arr.length; i += 1) { // loop by UUIDs
          achr = 0;
          rest = 0;
          next = arr[i].replace(new RegExp('-', 'g'), ''); // remove '-' characters from UUID
          item = subHexStr(next, prev); // calculate delta
          prev = next;

          if ((cutHexStr(item).length - 1) * 4 + strPow(cutHexStr(item).charAt(0)) < UNIT_LEN * 4 - pow) {
            item = cutHexStr(item);
          } // we use delimiter only if delta is less than UUID length minus one char

          for (j = item.length - 1; j >= 0; j -= 1) { // loop by delta characters
            curr = parseInt(item.charAt(j), 16); // get BBC
            achr += (curr << rest);

            if (j === 0 && item.length < UNIT_LEN) { // get BBC length (for the first character without leading zeros)
              rest += strPow(item.charAt(0));
            } else {
              rest += 4;
            }
            while (rest >= pow) { // create symbols to compressed string 
              powC = pow - 1; // try with a short symbol length
              code = parseInt(revString(((achr & ((1 << powC) - 1)) + (1 << powC)).toString(2)), 2) >> 1;

              if (code >= lowhi) { powC += 1; } // if we get code of long length symbols

              rest     -= powC; // decrease BBC length
              code      = parseInt(revString(((achr & ((1 << powC) - 1)) + (1 << powC)).toString(2)), 2) >> 1; // get reverse bits from the end of BBC to create new symbol
              dresult  += assoc(alpArr, code); // add new symbol
              achr    >>= powC; // remove used bits from BBC
            }
          }
          if (rest > 0) { // check if we have tail of BBC for current UUID
            code   = parseInt(revString(((achr & ((1 << rest) - 1)) + (1 << rest)).toString(2)), 2) >> 1; // try with a short symbol length
            code <<= (pow - rest - 1); // add zeros to get valid symbol code

            if (code >= lowhi) { code <<= 1; } // if we get code of long length symbols

            dresult += assoc(alpArr, code); // add tail symbol for current UUID
          }

          if (item.length < UNIT_LEN) {dresult += alpArr[0][1]; } // add delimiter if we use less symbols than for whole UUID
        }

      } else {

        order = true; // for single symbol alphabet we can choose only nresult
      }

      if ((dresult.length < nresult.length) && (!order)) { nresult = dresult; } // get better result or non delta if we need to keep order

      return nresult;
    },

    // decompress UUIDs array
    alpDecompress: function (str, alpStr) {
      // declare starting values
      var
      result = [],
      alpArr = alptoArr(alpStr, false), // get alphabet array without delimiter
      pow    = alpArr[0][2],
      lowhi  = alpArr[0][0],
      achr   = 0, // BBC
      rest   = 0, // BBC length
      item   = '', // buffer for UUIDs characters
      curr, // current UUID
      prev   = ('0').repeat(UNIT_LEN), // previous UUID for decompress with delta (at start is zero)
      i, // counter for loop
      code, // BBC bits of current character
      firstBit = true; // for the first bit removing if delta was not used

      if ((rassoc(alpArr, str.charAt(0)) & (1 << (tassoc(alpArr, str.charAt(0)) - 1))) === 0) { // check first bit to choose if delta used when compress

        // delta was not used
        for (i = 0; i < str.length; i += 1) { // loop by symbols of compressed string

          code  = parseInt(revString((rassoc(alpArr, str.charAt(i)) + (1 << tassoc(alpArr, str.charAt(i)))).toString(2)), 2) >> 1; // reverse symbol code to BBC bits
          achr += code << rest; // add bits to BBC
          rest += tassoc(alpArr, str.charAt(i)); // add BBC length

          if (firstBit) { // first bit processing
            firstBit = false;
            achr >>= 1;
            rest -= 1;
          }

          while (rest >= 4) { // add new UUID caracters to buffer
            rest -= 4; // decrease BBC length
            item = (achr & 15).toString(16) + item; // add new UUID character
            achr >>= 4; // remove used bits from BBC
          }

          if (item.length >= UNIT_LEN) { // if we get buffer with length equal or more than whole UUID
            curr = item.substr(item.length - UNIT_LEN, UNIT_LEN); // extract UUID from the end of buffer
            if (UNIT_LEN === 32) { // add '-' characters if we work with UUID
              curr = curr.substr(0, 8) + '-' + curr.substr(8, 4) + '-' + curr.substr(12, 4) + '-' + curr.substr(16, 4) + '-' + curr.substr(20, 12);
            }
            result[result.length] = curr; // add new UUID to array
            item = item.substr(0, item.length - UNIT_LEN); // remove used characters from buffer
          }

        }
      } else {

        // delta was used
        alpArr = alptoArr(alpStr, true); // get alphabet array with delimiter
        pow    = alpArr[0][2];
        lowhi  = alpArr[0][0];

        for (i = 1; i <= str.length; i += 1) { // loop by symbols of compressed string from second (the first is header) to next after last (for final buffer processing)
          if ((str.charAt(i) === alpArr[0][1]) || (item.length >= UNIT_LEN)) { // we catch delimiter or we get buffer length equal or more than whole UUID
            if (item.length >= UNIT_LEN) { // if buffer length than we need to look at the current symbol one more time (this pass we will not process it)
              i -= 1;
              item = item.substr(item.length - UNIT_LEN); // extract delta from the end of buffer
            } else {
              item = ('0').repeat(UNIT_LEN - item.length) + item; // if delimiter we add first zero characters to get whole UUID
            }

            curr = addHexStr(item, prev); // calculate UUID from delta
            prev = curr;

            if (UNIT_LEN === 32) { // add '-' characters if we work with UUID
              curr = curr.substr(0, 8) + '-' + curr.substr(8, 4) + '-' + curr.substr(12, 4) + '-' + curr.substr(16, 4) + '-' + curr.substr(20, 12);
            }

            result[result.length] = curr; // add new UUID to array
            achr = 0; // clear BBC and buffer
            rest = 0;
            item = '';

          } else {

            if (i < str.length) { // if we become last symbol we need no to symbol processing

              code  = parseInt(revString((rassoc(alpArr, str.charAt(i)) + (1 << tassoc(alpArr, str.charAt(i)))).toString(2)), 2) >> 1; // reverse symbol code to BBC bits
              achr += code << rest; // add bits to BBC
              rest += pow; // get number of bits in BBC

              if (code < lowhi) { rest -= 1; }

              while (rest >= 4) { // add new UUID caracters to buffer
                rest  -= 4; // decrease number of bits in BBC
                item   = (achr & 15).toString(16) + item; // add new UUID character
                achr >>= 4; // remove used bits from BBC
              }
            }
          }
        }
      }
      return result;
    }

  };

}));
