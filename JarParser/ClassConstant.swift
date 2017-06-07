//
//  ClassConstant.swift
//  JarParser
//
//  Created by Daniel DeCovnick on 6/17/15.
//  Copyright © 2015 Softyards. All rights reserved.
//

import Foundation


func readFromData<T: UnsignedInteger>(_ data: Data, cursor:inout Int) -> T {
    var temp : T = 0
    (data as NSData).getBytes(&temp, range: NSMakeRange(cursor, MemoryLayout<T>.size))
    cursor += MemoryLayout<T>.size
    return temp
}

class ClassConstant: NSObject {
    
    enum Tag : UInt8 {
        case classRef           = 7
        case fieldRef           = 9
        case methodRef          = 10
        case interfaceMethodRef = 11
        case stringRef          = 8
        case integer            = 3
        case float              = 4
        case long               = 5
        case double             = 6
        case nameAndType        = 12
        case utf8               = 1
        case methodHandle       = 15
        case methodType         = 16
        case invokeDynamic      = 18
    }
    
    let tag : Tag
    init(withTag tag:Tag) {
        self.tag = tag
        super.init()
    }
    static func withTag(_ tag : Tag, cursor : inout Int, data : Data) -> ClassConstant {
        switch tag {
        case .classRef:
            return ClassRefConstant(tag: tag, cursor: &cursor, data: data)
        case .fieldRef, .methodRef, .interfaceMethodRef:
            return MethodOrFieldRefConstant(tag: tag, cursor: &cursor, data: data)
        case .stringRef:
            return StringRefConstant(tag: tag, cursor: &cursor, data: data)
        case .integer:
            return IntegerConstant(tag: tag, cursor: &cursor, data: data)
        case .float:
            return FloatConstant(tag: tag, cursor: &cursor, data: data)
        case .long:
            return LongConstant(tag: tag, cursor: &cursor, data: data)
        case .double:
            return DoubleConstant(tag: tag, cursor: &cursor, data: data)
        case .nameAndType:
            return NameAndTypeConstant(tag: tag, cursor: &cursor, data: data)
        case .utf8:
            return Utf8Constant(tag: tag, cursor: &cursor, data: data)
        case .methodHandle:
            return MethodHandleConstant(tag: tag, cursor: &cursor, data: data)
        case .methodType:
            return MethodHandleConstant(tag: tag, cursor: &cursor, data: data)
        case .invokeDynamic:
            return InvokeDynamicConstant(tag: tag, cursor: &cursor, data: data)
        }
    }
}

class ClassRefConstant : ClassConstant {
    let nameIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class MethodOrFieldRefConstant : ClassConstant { // Tag will delineate FieldRef, MethodRef, and InterfaceMethodRef
    let classIndex : UInt16
    let nameAndTypeIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        classIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        nameAndTypeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class StringRefConstant : ClassConstant {
    let stringIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        stringIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class IntegerConstant : ClassConstant {
    let value : Int32
    init(tag:Tag, cursor:inout Int, data:Data) {
        value = Int32(NSSwapBigIntToHost(readFromData(data, cursor: &cursor)))
        super.init(withTag: tag)
    }
}

class FloatConstant : ClassConstant {
    let value : Float
    init(tag:Tag, cursor:inout Int, data:Data) {
        value = NSSwapBigFloatToHost(NSSwappedFloat(v: readFromData(data, cursor: &cursor)))
        super.init(withTag: tag)
    }
}

class LongConstant : ClassConstant {
    let value : Int64
    init(tag:Tag, cursor:inout Int, data:Data) {
        var temp4 : UInt32 = readFromData(data, cursor: &cursor)
        let localLong = UInt64(temp4) << 32
        temp4 = readFromData(data, cursor: &cursor)
        value = Int64(NSSwapBigLongLongToHost(localLong + UInt64(temp4)))
        super.init(withTag: tag)
    }
}

class DoubleConstant : ClassConstant {
    let value : Double
    init(tag:Tag, cursor:inout Int, data:Data) {
        var temp4 : UInt32 = readFromData(data, cursor: &cursor)
        var temp8 = UInt64(temp4) << 32
        temp4 = readFromData(data, cursor: &cursor)
        temp8 += UInt64(temp4)
        value = NSSwapBigDoubleToHost(NSSwappedDouble(v: temp8))
        super.init(withTag: tag)
    }
}

class NameAndTypeConstant : ClassConstant {
    let nameIndex : UInt16
    let descriptorIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class Utf8Constant : ClassConstant {
    let length : UInt16
    let string : NSString
    init(tag:Tag, cursor:inout Int, data:Data) {
        length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        string = NSString(data: (data as NSData).subdata(with: NSMakeRange(cursor, Int(length))), encoding: String.Encoding.utf8.rawValue)!
        // that's a little dangerous...
        cursor += Int(length)
        super.init(withTag: tag)
    }
}

class MethodHandleConstant: ClassConstant {
    
    enum Kind : UInt8 {
        case getField = 1
        case getStatic
        case putField
        case putStatic
        case invokeVirtual
        case invokeStatic
        case invokeSpecial
        case newInvokeSpecial
        case invokeInterface
    }
    
    let referenceKind : Kind
    let referenceIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        referenceKind = Kind(rawValue: readFromData(data, cursor: &cursor))!
        referenceIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class MethodTypeConstant : ClassConstant {
    let descriptorIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class InvokeDynamicConstant: ClassConstant {
    let bootstrapMethodAttrIndex : UInt16
    let nameAndTypeIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        bootstrapMethodAttrIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        nameAndTypeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}
