// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Base64 {

    // the string is a data type and internal means it can only be used within this contract and constant means that it cant be changed means that it is 
    // immutable and TABLE_ENCODE is the name of the variable also an identifier and the long text is a base64 alphabet when encoding bytes to base 64 characters
    string internal constant TABLE_ENCODE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    
    // the name of the function is encode and it takes an input called data which is stored in memory and the data type being 
    //passed is bytes and the visibilty is internal
    // and it pure which means it does not read or write state just calculate the input and the returns a string memory
    function encode(bytes memory data) internal pure returns (string memory) {

        // this checks if the length of the data from the input is equal to 0 return an empty string
        if (data.length == 0) return "";

        // now a datatype which is a string and then stored in memory and the name of the identifier is table which was beinf stored is TABLE_ENCODE
        string memory table = TABLE_ENCODE;

        // so the encodeLen(the identifier) which is a number so it needs to be an unsigned integer and the formula being used here is 
        // 4 * (data.length + 2)/3 
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // and now the datatype is a string and the identifier name is the result which is also a varible and the 
        // the result is a string and to allocate enough memory for the output
        string memory result = new string(encodedLen + 32);
        
        // assembly{} is a byte level optimization block(optimization control)
        assembly {
            // mstore(ptr, value) where ptr is the location of a box and value is what inside the box and mstore is the label
            // sp basically it write the label on a 32 byte value at a particular memeory address ptr where encodedLen is the value and result is the location
            mstore(result, encodedLen)


            // so it define and store a variable using the let keyword and the name of the variable is tablePtre and using the add keyword means table + 1
            let tablePtr := add(table, 1)

            // so it create a local assembly vairable named dataPtr and it initializes to the memory pointer of data 
            let dataPtr := data

            // a local assembly data and it means the addition of the declared assembly variables dataPtr + mload(data)(this means data.length)
            let endPtr := add(dataPtr, mload(data))

            // the resultPtr is the assembly local variable and the result is result + 32 
            let resultPtr := add(result, 32)

            // for loop or what 


            // for {init} condition {post} {body}

            // there is no input in the for loop and the condition is like a whileloop 
            // while (dataPtr < endPtr)
            // post body has nothing 

            for {} lt(dataPtr, endPtr) {}
            {
                // where dataPtr is the assembly local variable and is equal to dataPtr + 3
                dataPtr := add(dataPtr, 3)

                // let create a local assembly variable named input and then loads a 32 byte word memoey at dataPtr
                let input := mload(dataPtr)

                // mstore8(ptr, value) where ptr is the location and the value is what inside the box and the mstore8 create a label
               // shr(18, input) is it shift input by 18 bits towards the right 
               // and(..., 0x3F) keeps only the lowest 6 bits
               // add(tablePtr, index) pointer to one base64 char in lookup table
               // mload() reads that particular char
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}
