//
//  Annotation.swift
//  JarParser
//
//  Created by Daniel DeCovnick on 7/11/15.
//  Copyright © 2015 Softyards. All rights reserved.
//

import Foundation

extension AttributeInfo {
    struct Annotation {
        
        class ElementValuePair : NSObject {
            
            enum Tag : UInt8 {
                case Byte = "B"
                case Char = "C"
                case Double = "D"
                case Float = "F"
                case Integer = "I"
                case Long = "J"
                case Short = "S"
                case Boolean = "Z"
                case String = "s"
                case Enum = "e"
                case Class = "c"
                case Annotation = "@"
                case Array = "["
            }
            
            let tag : Tag
            static func fromData(data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) -> ElementValuePair {
                let tag = Tag(rawValue: readFromData(data, cursor: &cursor))!
                switch tag {
                case .Byte, .Char, .Double, .Float, .Integer, .Long, .Short, .Boolean, .String:
                    return ConstValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .Enum:
                    return EnumValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .Class:
                    return ClassValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .Annotation:
                    return AnnotationValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .Array:
                    return ArrayValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                }
            }
            init(tag:Tag) {
                self.tag = tag;
                super.init()
            }
        }
        
        class ConstValue: ElementValuePair {
            let constValueIndex : UInt16
            //cached
            let constant : ClassConstant
            init(tag:Tag, data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
                constValueIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                constant = constantPool[constValueIndex]!
                super.init(tag: tag)
            }
        }
        
        class EnumValue: ElementValuePair {
            let typeNameIndex : UInt16
            let constNameIndex : UInt16
            //cached
            let typeName : Utf8Constant
            let constName : Utf8Constant
            init(tag:Tag, data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
                typeNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                constNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                typeName = constantPool[typeNameIndex]! as! Utf8Constant
                constName = constantPool[constNameIndex]! as! Utf8Constant
                super.init(tag: tag)
            }
        }
        
        class ClassValue: ElementValuePair {
            let classInfoIndex : UInt16
            //cached
            let classInfo : ClassRefConstant
            init(tag:Tag, data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
                classInfoIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                classInfo = constantPool[classInfoIndex]! as! ClassRefConstant
                super.init(tag: tag)
            }
        }
        
        class AnnotationValue: ElementValuePair {
            let annotation : Annotation
            init(tag:Tag, data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
                annotation = Annotation(data: data, cursor: &cursor, constantPool: constantPool)
                super.init(tag: tag)
            }
        }
        
        class ArrayValue: ElementValuePair {
            let numValues : UInt16
            let values : [ElementValuePair]
            init(tag:Tag, data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
                numValues = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                var tempValues = [ElementValuePair]()
                for _ in 0..<numValues {
                    tempValues.append(ElementValuePair.fromData(data, cursor: &cursor, constantPool: constantPool))
                }
                values = tempValues
                super.init(tag: tag)
            }
        }
        
        let typeIndex : UInt16
        let numElementValuePairs : UInt16
        let elementValuePairs : [ElementValuePair]
        init(data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
            typeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            numElementValuePairs = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempEVPs = [ElementValuePair]()
            for _ in 0..<numElementValuePairs {
                tempEVPs.append(ElementValuePair.fromData(data, cursor: &cursor, constantPool: constantPool))
            }
            elementValuePairs = tempEVPs
        }
    }
    struct CountedAnnotations {
        let numAnnotations : UInt16
        let annotations : [Annotation]
        init(data:NSData, inout cursor:Int, constantPool:[UInt16: ClassConstant]) {
            numAnnotations = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempAnnotations = [Annotation]()
            for _ in 0..<numAnnotations {
                tempAnnotations.append(Annotation(data: data, cursor: &cursor, constantPool: constantPool))
            }
            annotations = tempAnnotations
        }
    }

}
