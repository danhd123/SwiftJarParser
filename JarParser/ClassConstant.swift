//
//  ClassConstant.swift
//  JarParser
//
//  Created by Daniel DeCovnick on 6/17/15.
//  Copyright © 2015 Softyards. All rights reserved.
//

import Foundation


func readFromData<T: UnsignedIntegerType>(data: NSData, inout cursor:Int) -> T {
    var temp : T = 0
    data.getBytes(&temp, range: NSMakeRange(cursor, sizeof(T)))
    cursor += sizeof(T)
    return temp
}

class ClassConstant: NSObject {
    
    enum Tag : UInt8 {
        case ClassRef           = 7
        case FieldRef           = 9
        case MethodRef          = 10
        case InterfaceMethodRef = 11
        case StringRef          = 8
        case Integer            = 3
        case Float              = 4
        case Long               = 5
        case Double             = 6
        case NameAndType        = 12
        case Utf8               = 1
        case MethodHandle       = 15
        case MethodType         = 16
        case InvokeDynamic      = 18
    }
    
    let tag : Tag
    init(withTag tag:Tag) {
        self.tag = tag
        super.init()
    }
    static func withTag(tag : Tag, inout cursor : Int, data : NSData) -> ClassConstant {
        switch tag {
        case .ClassRef:
            return ClassRefConstant(tag: tag, cursor: &cursor, data: data)
        case .FieldRef, .MethodRef, .InterfaceMethodRef:
            return MethodOrFieldRefConstant(tag: tag, cursor: &cursor, data: data)
        case .StringRef:
            return StringRefConstant(tag: tag, cursor: &cursor, data: data)
        case .Integer:
            return IntegerConstant(tag: tag, cursor: &cursor, data: data)
        case .Float:
            return FloatConstant(tag: tag, cursor: &cursor, data: data)
        case .Long:
            return LongConstant(tag: tag, cursor: &cursor, data: data)
        case .Double:
            return DoubleConstant(tag: tag, cursor: &cursor, data: data)
        case .NameAndType:
            return NameAndTypeConstant(tag: tag, cursor: &cursor, data: data)
        case .Utf8:
            return Utf8Constant(tag: tag, cursor: &cursor, data: data)
        case .MethodHandle:
            return MethodHandleConstant(tag: tag, cursor: &cursor, data: data)
        case .MethodType:
            return MethodHandleConstant(tag: tag, cursor: &cursor, data: data)
        case .InvokeDynamic:
            return InvokeDynamicConstant(tag: tag, cursor: &cursor, data: data)
        }
    }
}

class ClassRefConstant : ClassConstant {
    let nameIndex : UInt16
    init(tag:Tag, inout cursor:Int, data:NSData) {
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class MethodOrFieldRefConstant : ClassConstant { // Tag will delineate FieldRef, MethodRef, and InterfaceMethodRef
    let classIndex : UInt16
    let nameAndTypeIndex : UInt16
    init(tag:Tag, inout cursor:Int, data:NSData) {
        classIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        nameAndTypeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class StringRefConstant : ClassConstant {
    let stringIndex : UInt16
    init(tag:Tag, inout cursor:Int, data:NSData) {
        stringIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class IntegerConstant : ClassConstant {
    let value : Int32
    init(tag:Tag, inout cursor:Int, data:NSData) {
        value = Int32(NSSwapBigIntToHost(readFromData(data, cursor: &cursor)))
        super.init(withTag: tag)
    }
}

class FloatConstant : ClassConstant {
    let value : Float
    init(tag:Tag, inout cursor:Int, data:NSData) {
        value = NSSwapBigFloatToHost(NSSwappedFloat(v: readFromData(data, cursor: &cursor)))
        super.init(withTag: tag)
    }
}

class LongConstant : ClassConstant {
    let value : Int64
    init(tag:Tag, inout cursor:Int, data:NSData) {
        var temp4 : UInt32 = readFromData(data, cursor: &cursor)
        let localLong = UInt64(temp4) << 32
        temp4 = readFromData(data, cursor: &cursor)
        value = Int64(NSSwapBigLongLongToHost(localLong + UInt64(temp4)))
        super.init(withTag: tag)
    }
}

class DoubleConstant : ClassConstant {
    let value : Double
    init(tag:Tag, inout cursor:Int, data:NSData) {
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
    init(tag:Tag, inout cursor:Int, data:NSData) {
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class Utf8Constant : ClassConstant {
    let length : UInt16
    let string : NSString
    init(tag:Tag, inout cursor:Int, data:NSData) {
        length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        string = NSString(data: data.subdataWithRange(NSMakeRange(cursor, Int(length))), encoding: NSUTF8StringEncoding)!
        // that's a little dangerous...
        cursor += Int(length)
        super.init(withTag: tag)
    }
}

class MethodHandleConstant: ClassConstant {
    
    enum Kind : UInt8 {
        case GetField = 1
        case GetStatic
        case PutField
        case PutStatic
        case InvokeVirtual
        case InvokeStatic
        case InvokeSpecial
        case NewInvokeSpecial
        case InvokeInterface
    }
    
    let referenceKind : Kind
    let referenceIndex : UInt16
    init(tag:Tag, inout cursor:Int, data:NSData) {
        referenceKind = Kind(rawValue: readFromData(data, cursor: &cursor))!
        referenceIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class MethodTypeConstant : ClassConstant {
    let descriptorIndex : UInt16
    init(tag:Tag, inout cursor:Int, data:NSData) {
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class InvokeDynamicConstant: ClassConstant {
    let bootstrapMethodAttrIndex : UInt16
    let nameAndTypeIndex : UInt16
    init(tag:Tag, inout cursor:Int, data:NSData) {
        bootstrapMethodAttrIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        nameAndTypeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}
