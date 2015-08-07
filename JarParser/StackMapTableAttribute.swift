//
//  StackMapTableAttribute.swift
//  JarParser
//
//  Created by Daniel DeCovnick on 7/7/15.
//  Copyright © 2015 Softyards. All rights reserved.
//

import Foundation

class StackMapTableAttribute: AttributeInfo {
    
    class StackMapFrame: NSObject {
        
        enum Tag {
            case Same(UInt8)
            case SameLocals1StackItem(UInt8)
            case SameLocals1StackItemExtended
            case Chop(UInt8)
            case SameFrameExtended
            case Append(UInt8)
            case FullFrame
            static func fromRaw(rawValue:UInt8) -> Tag? {
                switch rawValue {
                case 0...63:
                    return Same(rawValue)
                case 64...127:
                    return SameLocals1StackItem(rawValue)
                case 247:
                    return SameLocals1StackItemExtended
                case 248...250:
                    return Chop(rawValue)
                case 251:
                    return SameFrameExtended
                case 252...254:
                    return Append(rawValue)
                case 255:
                    return FullFrame
                default:
                    return nil
                }
            }
            func value() -> UInt8 {
                switch self {
                case let .Same(rawValue):
                    return rawValue
                case let .SameLocals1StackItem(rawValue):
                    return rawValue
                case .SameLocals1StackItemExtended:
                    return 247
                case let .Chop(rawValue):
                    return rawValue
                case .SameFrameExtended:
                    return 251
                case let .Append(rawValue):
                    return rawValue
                case .FullFrame:
                    return 255
                }
            }
        }
        
        enum VerificationTypeInfo {
            case Top
            case Integer
            case Float
            case Long
            case Double
            case Null
            case Object(UInt16)
            case Uninitialized(UInt16)
            static func fromRaw(rawValue:UInt8, poolIndexOrOffset:UInt16 = 0) -> VerificationTypeInfo? {
                switch rawValue {
                case 0:
                    return Top
                case 1:
                    return Integer
                case 2:
                    return Float
                case 4: // *sigh*
                    return Long
                case 3: //yes really
                    return Double
                case 5:
                    return Null
                case 6:
                    return Object(poolIndexOrOffset)
                case 7:
                    return Uninitialized(poolIndexOrOffset)
                default:
                    return nil
                }
            }
            
        }
        
        let frameType : Tag
        init(frameType:Tag) {
            self.frameType = frameType
            super.init()
        }
        
        static func readVerificationTypeInfoFromData(data:NSData, inout cursor:Int) -> VerificationTypeInfo? {
            let temp1 : UInt8 = readFromData(data, cursor: &cursor)
            if temp1 == 6 || temp1 == 7 {
                return VerificationTypeInfo.fromRaw(temp1, poolIndexOrOffset: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            }
            else {
                return VerificationTypeInfo.fromRaw(temp1)
            }
            
        }
        
        static func fromData(data:NSData, inout cursor:Int) -> StackMapFrame? {
            let tag : StackMapFrame.Tag = StackMapFrame.Tag.fromRaw(readFromData(data, cursor: &cursor))!
            switch tag {
            case .Same:
                return SameFrame(frameType: tag)
            case .SameLocals1StackItem:
                return SameLocals1StackItemFrame(frameType: tag, data: data, cursor: &cursor)
            default:
                return nil
            }
        }
    }
    
    class SameFrame: StackMapFrame {
    }
    
    class SameLocals1StackItemFrame: StackMapFrame {
        let stackItem : VerificationTypeInfo
        init(frameType: Tag, data:NSData, inout cursor:Int) {
            let temp1 : UInt8 = readFromData(data, cursor: &cursor)
            if temp1 == 6 || temp1 == 7 {
                stackItem = VerificationTypeInfo.fromRaw(temp1, poolIndexOrOffset: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))!
            }
            else {
                stackItem = VerificationTypeInfo.fromRaw(temp1)!
            }
            super.init(frameType: frameType)
        }
    }
    
    class SameLocals1StackItemFrameExtended: StackMapFrame {
        let offsetDelta : UInt16
        let stackItem : VerificationTypeInfo
        init(frameType: Tag, data:NSData, inout cursor:Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            stackItem = StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor)!
            super.init(frameType: frameType)
        }
    }
    
    class ChopFrame: StackMapFrame {
        let offsetDelta : UInt16
        init(frameType: Tag, data:NSData, inout cursor:Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            super.init(frameType: frameType)
        }
    }
    
    class SameFrameExtended: StackMapFrame {
        let offsetDelta : UInt16
        init(frameType: Tag, data:NSData, inout cursor:Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            super.init(frameType: frameType)
        }
    }
    
    class AppendFrame: StackMapFrame {
        let offsetDelta : UInt16
        let locals : [VerificationTypeInfo]
        init(frameType: Tag, data:NSData, inout cursor:Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            let k = frameType.value() - 251
            var tempLocals = [VerificationTypeInfo]()
            for _ in 0..<k {
                tempLocals.append(StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor)!)
            }
            locals = tempLocals
            super.init(frameType: frameType)
        }
    }
    
    class FullFrame: StackMapFrame {
        let offsetDelta : UInt16
        let numberOfLocals : UInt16
        let locals : [VerificationTypeInfo]
        let numberOfStackItems : UInt16
        let stack : [VerificationTypeInfo]
        init(frameType: Tag, data:NSData, inout cursor:Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            numberOfLocals = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempLocals = [VerificationTypeInfo]()
            for _ in 0..<numberOfLocals {
                tempLocals.append(StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor)!)
            }
            locals = tempLocals
            numberOfStackItems = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempStack = [VerificationTypeInfo]()
            for _ in 0..<numberOfStackItems {
                tempStack.append(StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor)!)
            }
            stack = tempStack
            super.init(frameType: frameType)
        }
        
    }
    
    let numberOfEntries : UInt16
    let entries : [StackMapFrame]
    init(header:Header, data:NSData, inout cursor:Int) {
        numberOfEntries = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localEntries = [StackMapFrame]()
        for _ in 0..<numberOfEntries {
            localEntries.append(StackMapFrame.fromData(data, cursor:&cursor)!)
        }
        entries = localEntries
        super.init(header: header)
    }
}
