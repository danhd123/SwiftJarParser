//
//  ClassFile.swift
//  JarParser
//
//  Created by Daniel DeCovnick on 6/16/15.
//  Copyright © 2015 Softyards. All rights reserved.
//

import Foundation


struct ClassFile {
    
    struct AccessFlags: OptionSetType {
        let rawValue: UInt16
        init(rawValue: UInt16) { self.rawValue = rawValue }
        
        static var None         : AccessFlags { return AccessFlags(rawValue: 0x0000) }
        static var Public       : AccessFlags { return AccessFlags(rawValue: 0x0001) }
        static var Final        : AccessFlags { return AccessFlags(rawValue: 0x0010) }
        static var Super        : AccessFlags { return AccessFlags(rawValue: 0x0020) }
        static var Interface    : AccessFlags { return AccessFlags(rawValue: 0x0200) }
        static var Abstract     : AccessFlags { return AccessFlags(rawValue: 0x0400) }
        static var Synthetic    : AccessFlags { return AccessFlags(rawValue: 0x1000) }
        static var Annotation   : AccessFlags { return AccessFlags(rawValue: 0x2000) }
        static var Enum         : AccessFlags { return AccessFlags(rawValue: 0x4000) }
        
    }
    
    let data : NSData
    let magic : UInt32
    let minorVersion : UInt16
    let majorVersion : UInt16
    let constantPoolCount : UInt16
    let constantPool : [UInt16: ClassConstant]
    let accessFlags : AccessFlags
    let thisClassIndex : UInt16
    let superClassIndex : UInt16
    let interfacesCount : UInt16
    let interfaceIndicies : [UInt16]
    let fieldsCount : UInt16
    let fields : [FieldInfo]
    let methodsCount : UInt16
    let methods : [MethodInfo]
    let attributesCount : UInt16
    let attributes : [AttributeInfo]
    init?(withData data:NSData) {
        if (data.length < 10) {
            return nil
        }
        var cursor = 0
        self.data = data
        (magic, minorVersion, majorVersion, constantPoolCount) = ClassFile.parseHeader(&cursor, data:self.data)
        var constants = [UInt16: ClassConstant]()
        for var i in 1...constantPoolCount {
            let tag = ClassConstant.Tag(rawValue: readFromData(data, cursor: &cursor))
            let constant = ClassConstant.withTag(tag!, cursor: &cursor, data: self.data)
            constants[i] = constant
            if (constant.tag == ClassConstant.Tag.Long || constant.tag == ClassConstant.Tag.Double) {
                i++
            }
        }
        constantPool = constants
        accessFlags = AccessFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        thisClassIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        superClassIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        interfacesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempIndicies : [UInt16] = []
        for _ in 0..<interfacesCount {
            tempIndicies.append(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        }
        interfaceIndicies = tempIndicies
        
        fieldsCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempFields = [FieldInfo]()
        for _ in 0..<fieldsCount {
            tempFields.append(FieldInfo(data: data, cursor: &cursor, constantPool:constantPool))
        }
        fields = tempFields
        
        methodsCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempMethods = [MethodInfo]()
        for _ in 0..<methodsCount {
            tempMethods.append(MethodInfo(data: data, cursor: &cursor, constantPool:constantPool))
        }
        methods = tempMethods
        
        attributesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempAttrs = [AttributeInfo]()
        for _ in 0..<attributesCount {
            tempAttrs.append(AttributeInfo.fromData(data, cursor: &cursor, constantPool: constantPool))
        }
        attributes = tempAttrs
    }
    
    static func parseHeader(inout cursor:Int, data:NSData) -> (UInt32, UInt16, UInt16, UInt16) {
        let magic = NSSwapBigIntToHost(readFromData(data, cursor: &cursor))
        assert(magic == 0xCAFEBABE, "This is not a Java class file")
        let minorVersion = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        let majorVersion = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        let constantPoolCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        return (magic, minorVersion, majorVersion, constantPoolCount);
    }
}