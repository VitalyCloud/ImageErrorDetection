
// Using UInt8 as Byte
import Foundation


typealias Byte = UInt8

extension Byte {
    var bits: [Bit] {
        let bitsOfAbyte = 8
        var bitsArray = [Bit](repeating: Bit.zero, count: bitsOfAbyte)
        for (index, _) in bitsArray.enumerated() {
            // Bitwise shift to clear unrelevant bits
            let bitVal: UInt8 = 1 << UInt8(bitsOfAbyte - 1 - index)
            let check = self & bitVal
            
            if check != 0 {
                bitsArray[index] = Bit.one
            }
        }
        return bitsArray
    }
}

//нету
enum Bit: UInt8 {
    case zero = 0
    case one = 1
    
    func invert() -> Bit {
        if self == .one {
            return .zero
        } else {
            return .one
        }
    }
}

extension Data {
    var bytes: [Byte] {
        var byteArray = [UInt8](repeating: 0, count: self.count)
        self.copyBytes(to: &byteArray, count: self.count)
        return byteArray
    }
    
    static func bitsToBytes(bits: [Bit]) -> [UInt8] {
        let numBits = bits.count
        let numBytes = (numBits + 7)/8
        var bytes = [UInt8](repeating : 0, count : numBytes)
        
        for (index, bit) in bits.enumerated() {
            if bit == .one {
                bytes[index / 8] += 1 << (7 - index % 8)
            }
        }
        
        return bytes
    }
}




