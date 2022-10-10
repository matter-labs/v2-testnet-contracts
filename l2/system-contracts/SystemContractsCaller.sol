// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8;

import "./Constants.sol";

// Addresses used for the compiler to be replaced with the 
// zkSync-specific opcodes during the compilation.
// IMPORTANT: these are just compile-time constants and are used
// only if used in-place by Yul optimizer.
address constant TO_L1_CALL_ADDRESS = address((1<<16) - 1);
address constant CODE_ADDRESS_CALL_ADDRESS = address((1<<16) - 2);
address constant PRECOMPILE_CALL_ADDRESS = address((1<<16) - 3);
address constant META_CALL_ADDRESS = address((1<<16) - 4);
address constant MIMIC_CALL_CALL_ADDRESS = address((1<<16) - 5);
address constant SYSTEM_MIMIC_CALL_CALL_ADDRESS = address((1<<16) - 6);
address constant MIMIC_CALL_BY_REF_CALL_ADDRESS = address((1<<16) - 7);
address constant SYSTEM_MIMIC_CALL_BY_REF_CALL_ADDRESS = address((1<<16) - 8);
address constant RAW_FAR_CALL_CALL_ADDRESS = address((1<<16) - 9);
address constant RAW_FAR_CALL_BY_REF_CALL_ADDRESS = address((1<<16) - 10);
address constant SYSTEM_CALL_CALL_ADDRESS = address((1<<16) - 11);
address constant SYSTEM_CALL_BY_REF_CALL_ADDRESS = address((1<<16) - 12);
address constant SET_CONTEXT_VALUE_CALL_ADDRESS = address((1<<16) - 13);
address constant SET_PUBDATA_PRICE_CALL_ADDRESS = address((1<<16) - 14);
address constant INCREMENT_TX_COUNTER_CALL_ADDRESS = address((1<<16) - 15);
address constant PTR_CALLDATA_CALL_ADDRESS = address((1<<16) - 16);
address constant CALLFLAGS_CALL_ADDRESS = address((1<<16) - 17);
address constant GET_EXTRA_ABI_DATA_1_ADDRESS = address((1<<16) - 18);
address constant GET_EXTRA_ABI_DATA_2_ADDRESS = address((1<<16) - 19);
address constant PTR_RETURNDATA_CALL_ADDRESS = address((1<<16) - 20);
address constant LOAD_CALLDATA_INTO_ACTIVE_PTR_CALL_ADDRESS = address((1<<16) - 21);
address constant LOAD_LATEST_RETURNDATA_INTO_ACTIVE_PTR_CALL_ADDRESS = address((1<<16) - 22);
address constant PTR_ADD_INTO_ACTIVE_CALL_ADDRESS = address((1<<16) - 23);
address constant PTR_SHRINK_INTO_ACTIVE_CALL_ADDRESS = address((1<<16) - 24);
address constant PTR_PACK_INTO_ACTIVE_CALL_ADDRESS = address((1<<16) - 25);

// All the offsets are in bits
uint256 constant META_ERGS_PER_PUBDATA_BYTE_OFFSET = 0*8;
uint256 constant META_HEAP_SIZE_OFFSET = 8*8;
uint256 constant META_AUX_HEAP_SIZE_OFFSET = 12*8;
uint256 constant META_SHARD_ID_OFFSET = 28*8;
uint256 constant META_CALLER_SHARD_ID_OFFSET = 29*8;
uint256 constant META_CODE_SHARD_ID_OFFSET = 30*8;

enum CalldataForwardingMode {
    UseHeap,
    ForwardFatPointer,
    UseAuxHeap
}

// A library that should be available publicly and be used to call
// zkSync system contracts by users.
library SystemContractsCaller {
    // Makes a call with "system" flag.
    function systemCall(
        uint32 ergsLimit,
        address to,
        uint128 value,
        bytes memory data
    ) internal returns (bytes memory returnData) {
        address callAddr = SYSTEM_CALL_CALL_ADDRESS;

        uint32 dataStart;
        assembly {
            dataStart := add(data, 0x20)
        }
        uint32 dataLength = uint32(uint24(data.length));

        uint256 farCallAbi = SystemContractsCaller.getFarCallABI(
            0,
            0,
            dataStart,
            dataLength,
            ergsLimit,
            // Only rollup is supported for now
            0,
            CalldataForwardingMode.UseHeap,
            false,
            true
        );

        uint size = 0;
        bool success;
        if (value == 0) {
            // Doing the system call directly
            assembly {
                success := call(to, callAddr, 0, 0, farCallAbi, 0, 0)
            }
        } else {
            require(value <= MSG_VALUE_SIMULATOR_IS_SYSTEM_BIT, "Value can not be greater than 2**128");
            // We must direct the call through the MSG_VALUE_SIMULATOR
            // The first abi param for the MSG_VALUE_SIMULATOR carries 
            // the value of the call and whether the call should be a system one 
            // (in our case, it should be)
            uint256 abiParam1 = (MSG_VALUE_SIMULATOR_IS_SYSTEM_BIT | value); 

            // The second abi param carries the address to call.
            uint256 abiParam2 = uint256(uint160(to)); 

            address msgValueSimulator = MSG_VALUE_SYSTEM_CONTRACT;
            assembly {
                success := call(msgValueSimulator, callAddr, abiParam1, abiParam2, farCallAbi, 0, 0)
            }
        }

        assembly {
            size := returndatasize()
            if eq(success, 0) {
                returndatacopy(0, 0, size)
                revert(0, size)
            }
        }

        returnData = new bytes(size);
        assembly {
            mstore(returnData, size)
            returndatacopy(add(returnData, 0x20), 0, size)
        }
    }

    // A packed representation of the following data structure:
    // pub struct FarCallABI {
    //     pub memory_quasi_fat_pointer: FatPointer,
    //     pub ergs_passed: u32,
    //     pub shard_id: u8,
    //     pub forwarding_mode: FarCallForwardPageType,
    //     pub constructor_call: bool,
    //     pub to_system: bool,
    // }
    //
    // The FatPointer struct:
    // 
    // pub struct FatPointer {
    //     pub offset: u32, // offset relative to `start`
    //     pub memory_page: u32, // memory page where slice is located
    //     pub start: u32, // absolute start of the slice
    //     pub length: u32, // length of the slice
    // }
    //
    // Note, that the actual layout is the following:
    // 
    // [0..32) bits -- the calldata offset
    // [32..64) bits -- the memory page to use. Can be left blank in most of the cases.
    // [64..96) bits -- the absolute start of the slice
    // [96..128) bits -- the length of the slice.
    // [128..196) bits -- empty bits.
    // [196..224) bits -- ergsPassed.
    // [224..232) bits -- shard id.
    // [232..240) bits -- forwarding_mode
    // [240..248) bits -- constructor call flag
    // [248..256] bits -- system call flag
    function getFarCallABI(
        uint32 dataOffset,
        uint32 memoryPage,
        uint32 dataStart,
        uint32 dataLength,
        uint32 ergsPassed,
        uint8 shardId,
        CalldataForwardingMode forwardingMode,
        bool isConstructorCall,
        bool isSystemCall
    ) internal pure returns (uint256 result) {
        assembly {
            // The data offset
            result := shl(0, dataOffset)
            result := or(result, shl(32, memoryPage))
            result := or(result, shl(64, dataStart))
            result := or(result, shl(96, dataLength))

            result := or(result, shl(196, ergsPassed))
            result := or(result, shl(224, shardId))
            result := or(result, shl(232, forwardingMode))
            result := or(result, shl(240, isConstructorCall))
            result := or(result, shl(248, isSystemCall))
        }
    }
}
