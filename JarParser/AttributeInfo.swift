//
//  AttributeInfo.swift
//  JarParser
//
//  Created by Daniel DeCovnick on 7/6/15.
//  Copyright © 2015 Softyards. All rights reserved.
//

import Foundation

extension UInt8 : ExpressibleByStringLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String
    
    public init(stringLiteral value: StringLiteralType){
        self.init(([UInt8]() + value.utf8)[0])
    }
    
    public init(extendedGraphemeClusterLiteral value: String){
        self.init(([UInt8]() + value.utf8)[0])
    }
    
    public init(unicodeScalarLiteral value: String){
        self.init(([UInt8]() + value.utf8)[0])
    }
}

class AttributeInfo : NSObject {
    struct Header {
        let attributeNameIndex : UInt16
        let attributeLength : UInt32
        init(data:Data, cursor:inout Int) {
            attributeNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            attributeLength = NSSwapBigIntToHost(readFromData(data, cursor: &cursor))
        }
    }
    
    let header : Header
    init(header:Header) {
        self.header = header
        super.init()
    }
    static func fromData(_ data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) -> AttributeInfo {
        let header = AttributeInfo.Header(data: data, cursor: &cursor)
        switch (constantPool[header.attributeNameIndex]! as! Utf8Constant).string {
        case "ConstantValue":
            return ConstantValueAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Code":
            return CodeAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "StackMapTable":
            return StackMapTableAttribute(header: header, data: data, cursor: &cursor)
        case "Exceptions":
            return ExceptionTableAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "InnerClasses":
            return InnerClassAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "EnclosingMethod":
            return EnclosingMethodAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Synthetic":
            return SyntheticAttribute(header: header)
        case "Signature":
            return SignatureAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "SourceFile":
            return SourceFileAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "SourceDebugExtension":
            return SourceDebugExtension(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "LineNumberTable":
            return LineNumberTableAttribute(header: header, data: data, cursor: &cursor)
        case "LocalVariableTable":
            return LocalVariableTableAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "LocalVariableTypeTable":
            return LocalVariableTypeTableAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Deprecated":
            return DeprecatedAttribute(header: header)
        case "RuntimeVisibleAnnotations":
            return RuntimeVisibleAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeInvisibleAnnotations":
            return RuntimeInvisibleAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeVisibleParamterAnnotations":
            return RuntimeVisibleParameterAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeInvisibleParameterAnnotations":
            return RuntimeInvisibleParameterAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "AnnotationDefault":
            return AnnotationDefaultAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "BootstrapMethods":
            return BootstrapMethodsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        default:
            return UnknownAttribute(header: header, data: data, cursor: &cursor)
        }
    }
}

class ConstantValueAttribute : AttributeInfo {
    let constantValueIndex : UInt16
    let classConstant : ClassConstant //ooh, caching!
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        constantValueIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        classConstant = constantPool[constantValueIndex]!
        super.init(header: header)
    }
}

class CodeAttribute: AttributeInfo {
    
    struct ExceptionEntry {
        let startPC : UInt16
        let endPC : UInt16
        let handlerPC : UInt16
        let catchType : UInt16
        init(data:Data, cursor:inout Int) {
            startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            endPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            handlerPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            catchType = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        }
    }
    
    let maxStack : UInt16
    let maxLocals : UInt16
    let codeLength : UInt32
    let code : Data
    let exceptionTableLength : UInt16
    let exceptionTable : [ExceptionEntry]
    let attributesCount : UInt16
    let attributes : [AttributeInfo]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        maxStack = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        maxLocals = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        codeLength = NSSwapBigIntToHost(readFromData(data, cursor: &cursor))
        code = (data as NSData).subdata(with: NSMakeRange(cursor, Int(codeLength)))
        cursor += Int(codeLength)
        exceptionTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localTable = [ExceptionEntry]()
        for _ in 0..<exceptionTableLength {
            localTable.append(ExceptionEntry(data: data, cursor: &cursor))
        }
        exceptionTable = localTable
        attributesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localAttrs = [AttributeInfo]()
        for _ in 0..<attributesCount {
            localAttrs.append(AttributeInfo.fromData(data, cursor: &cursor, constantPool: constantPool))
        }
        attributes = localAttrs
        super.init(header: header)
    }
}

class ExceptionTableAttribute: AttributeInfo {
    let numberOfExceptions : UInt16
    let exceptionIndexTable : [UInt16]
    let exceptions : [ClassRefConstant]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        numberOfExceptions = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localIndexes = [UInt16]()
        for _ in 0..<numberOfExceptions {
            localIndexes.append(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        }
        exceptionIndexTable = localIndexes
        exceptions = exceptionIndexTable.map() { index in
            constantPool[index] as! ClassRefConstant
        }
        super.init(header: header)
    }
}

class InnerClassAttribute: AttributeInfo {
    
    struct InnerClass {
        
        struct AccessFlags: OptionSet {
            let rawValue: UInt16
            init(rawValue: UInt16) { self.rawValue = rawValue }
            
            static var None         : AccessFlags { return AccessFlags(rawValue: 0x0000) }
            static var Public       : AccessFlags { return AccessFlags(rawValue: 0x0001) }
            static var Private      : AccessFlags { return AccessFlags(rawValue: 0x0002) }
            static var Protected    : AccessFlags { return AccessFlags(rawValue: 0x0004) }
            static var Static       : AccessFlags { return AccessFlags(rawValue: 0x0008) }
            static var Final        : AccessFlags { return AccessFlags(rawValue: 0x0010) }
            static var Interface    : AccessFlags { return AccessFlags(rawValue: 0x0200) }
            static var Abstract     : AccessFlags { return AccessFlags(rawValue: 0x0400) }
            static var Synthetic    : AccessFlags { return AccessFlags(rawValue: 0x1000) }
            static var Annotation   : AccessFlags { return AccessFlags(rawValue: 0x2000) }
            static var Enum         : AccessFlags { return AccessFlags(rawValue: 0x4000) }
            
        }

        let innerClassInfoIndex : UInt16
        let outerClassInfoIndex : UInt16
        let innerNameIndex : UInt16
        let innerClassAccessFlagss : AccessFlags
        // cached types:
        let innerClassRef : ClassRefConstant
        let outerClassRef : ClassRefConstant?
        let innerName : Utf8Constant?
        init(data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
            innerClassInfoIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            outerClassInfoIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            innerNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            innerClassAccessFlagss = AccessFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            innerClassRef = constantPool[innerClassInfoIndex]! as! ClassRefConstant
            outerClassRef = constantPool[outerClassInfoIndex] as? ClassRefConstant
            innerName = constantPool[innerNameIndex] as? Utf8Constant
        }
    }
    
    let numberOfClasses : UInt16
    let classes : [InnerClass]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        numberOfClasses = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localClasses = [InnerClass]()
        for _ in 0..<numberOfClasses {
            localClasses.append(InnerClass(data: data, cursor: &cursor, constantPool: constantPool))
        }
        classes = localClasses
        super.init(header: header)
    }
}

class EnclosingMethodAttribute: AttributeInfo {
    let classIndex : UInt16
    let methodIndex : UInt16
    //cached types:
    let classRef : ClassRefConstant
    let methodRef : NameAndTypeConstant? // yes really
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        classIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        methodIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        classRef = constantPool[classIndex]! as! ClassRefConstant
        methodRef = constantPool[methodIndex] as? NameAndTypeConstant
        super.init(header: header)
    }
}

class SyntheticAttribute: AttributeInfo {
}

class SignatureAttribute: AttributeInfo {
    let signatureIndex : UInt16
    //cached:
    let signature : Utf8Constant
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        signatureIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        signature = constantPool[signatureIndex]! as! Utf8Constant
        super.init(header: header)
    }
}

class SourceFileAttribute: AttributeInfo {
    let sourceFileIndex : UInt16
    //cached:
    let sourceFile : Utf8Constant
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        sourceFileIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        sourceFile = constantPool[sourceFileIndex]! as! Utf8Constant
        super.init(header: header)
    }
}

class SourceDebugExtension: AttributeInfo {
    let debugExtension : Data
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        debugExtension = (data as NSData).subdata(with: NSMakeRange(cursor, Int(header.attributeLength)))
        cursor += Int(header.attributeLength)
        super.init(header: header)
    }
}
class LineNumberTableAttribute: AttributeInfo {
    
    struct LineNumberEntry {
        let startPC : UInt16
        let lineNumber : UInt16
        init(startPC:UInt16, lineNumber:UInt16) {
            self.startPC = startPC
            self.lineNumber = lineNumber
        }
    }
    
    let lineNumberTableLength : UInt16
    let lineNumberTable : [LineNumberEntry]
    init(header:Header, data:Data, cursor:inout Int) {
        lineNumberTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localTable = [LineNumberEntry]()
        for _ in 0..<lineNumberTableLength {
            let startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            let lineNumber = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            localTable.append(LineNumberEntry(startPC:startPC, lineNumber:lineNumber))
        }
        lineNumberTable = localTable
        super.init(header: header)
    }
}

class LocalVariableTableAttribute: AttributeInfo {
    
    struct LocalVariableEntry {
        let startPC : UInt16
        let length : UInt16
        let nameIndex : UInt16
        let descriptorIndex : UInt16
        let index : UInt16
        //cached:
        let name : Utf8Constant
        let descriptor : Utf8Constant
        init(data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
            startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            name = constantPool[nameIndex]! as! Utf8Constant
            descriptor = constantPool[descriptorIndex]! as! Utf8Constant
        }
    }
    
    let localVariableTableLength : UInt16
    let localVariableTable : [LocalVariableEntry]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        localVariableTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempTable = [LocalVariableEntry]()
        for _ in 0..<localVariableTableLength {
            tempTable.append(LocalVariableEntry(data: data, cursor: &cursor, constantPool: constantPool))
        }
        localVariableTable = tempTable
        super.init(header: header)
    }
}

class LocalVariableTypeTableAttribute: AttributeInfo {
    
    struct LocalVariableEntry {
        let startPC : UInt16
        let length : UInt16
        let nameIndex : UInt16
        let signatureIndex : UInt16
        let index : UInt16
        //cached:
        let name : Utf8Constant
        let signature : Utf8Constant
        init(data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
            startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            signatureIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            name = constantPool[nameIndex]! as! Utf8Constant
            signature = constantPool[signatureIndex]! as! Utf8Constant
        }
    }
    
    let localVariableTableLength : UInt16
    let localVariableTable : [LocalVariableEntry]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        localVariableTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempTable = [LocalVariableEntry]()
        for _ in 0..<localVariableTableLength {
            tempTable.append(LocalVariableEntry(data: data, cursor: &cursor, constantPool: constantPool))
        }
        localVariableTable = tempTable
        super.init(header: header)
    }
}

class DeprecatedAttribute: AttributeInfo {
}

class RuntimeVisibleAnnotationsAttribute: AttributeInfo {
    let annotations : CountedAnnotations
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        annotations = CountedAnnotations(data:data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class RuntimeInvisibleAnnotationsAttribute: AttributeInfo {
    let annotations : CountedAnnotations
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        annotations = CountedAnnotations(data:data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class RuntimeVisibleParameterAnnotationsAttribute: AttributeInfo {
    let numParameters : UInt8
    let paramaterAnnotations : [CountedAnnotations]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        numParameters = readFromData(data, cursor: &cursor)
        var tempParams = [CountedAnnotations]()
        for _ in 0..<numParameters {
            tempParams.append(CountedAnnotations(data: data, cursor: &cursor, constantPool: constantPool))
        }
        paramaterAnnotations = tempParams;
        super.init(header: header)
    }
}

class RuntimeInvisibleParameterAnnotationsAttribute: AttributeInfo {
    let numParameters : UInt8
    let paramaterAnnotations : [CountedAnnotations]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        numParameters = readFromData(data, cursor: &cursor)
        var tempParams = [CountedAnnotations]()
        for _ in 0..<numParameters {
            tempParams.append(CountedAnnotations(data: data, cursor: &cursor, constantPool: constantPool))
        }
        paramaterAnnotations = tempParams;
        super.init(header: header)
    }
}

class AnnotationDefaultAttribute: AttributeInfo {
    let defaultValue : Annotation.ElementValuePair
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        defaultValue = Annotation.ElementValuePair.fromData(data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class BootstrapMethodsAttribute: AttributeInfo {
    struct BootstrapMethod {
        let bootstrapMethodRefIndex : UInt16
        let numBootstrapArguments : UInt16
        let bootstrapArgumentsIndexes : [UInt16]
        //cached:
        let bootstrapMethodRef : MethodOrFieldRefConstant
        let bootstrapArguments : [ClassConstant]
        init(data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
            bootstrapMethodRefIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            numBootstrapArguments = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempIndicies = [UInt16]()
            for _ in 0..<numBootstrapArguments {
                tempIndicies.append(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            }
            bootstrapArgumentsIndexes = tempIndicies
            
            bootstrapMethodRef = constantPool[bootstrapMethodRefIndex]! as! MethodOrFieldRefConstant
            bootstrapArguments = bootstrapArgumentsIndexes.map() { index in
                constantPool[index] as! ClassRefConstant
            }
        }
    }
    
    let numBootstrapMethods : UInt16
    let bootstrapMethods : [BootstrapMethod]
    init(header:Header, data:Data, cursor:inout Int, constantPool:[UInt16: ClassConstant]) {
        numBootstrapMethods = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempMethods = [BootstrapMethod]()
        for _ in 0..<numBootstrapMethods {
            tempMethods.append(BootstrapMethod(data: data, cursor: &cursor, constantPool: constantPool))
        }
        bootstrapMethods = tempMethods
        super.init(header: header)
    }
}

class UnknownAttribute: AttributeInfo {
    let info : Data
    init(header:Header, data:Data, cursor:inout Int) {
        info = (data as NSData).subdata(with: NSMakeRange(cursor, Int(header.attributeLength)))
        cursor += Int(header.attributeLength)
        super.init(header: header)
    }
}



