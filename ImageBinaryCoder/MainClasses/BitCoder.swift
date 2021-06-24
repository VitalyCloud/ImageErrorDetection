
import Cocoa

class BitCoder: NSObject {
    
    var doubleRate:Int = 3
    private var decodeCompletion:((_ decodedBytes:[Byte]) -> Void)?
    var byteIndexesWithErrors:[Int] = []
    var threadsCount:Int = 1
    
    var decodedSubSequences:[Int:[Bit]] = [:] {
        didSet {
            
            if decodedSubSequences.keys.count == threadsCount {
                //operation did finish
                debug("Ended decoding")
                
                var decodedBits = [Bit]()
                for i in 0..<threadsCount {
                    decodedBits.append(contentsOf: decodedSubSequences[i]!)
                }
                
                debug("Output bits count: \(decodedBits.count)", inConsole: true)
                //преобразуем раскодированные биты в байты
                let decodedBytes = Data.bitsToBytes(bits: decodedBits)
                debug("Output bytes count: \(decodedBytes.count)", inConsole: true)
                
                debug("Fixed byte count: \(self.byteIndexesWithErrors.count)", inConsole: true)
                
                self.decodeCompletion?(decodedBytes)
                
                decodedSubSequences = [:]
            }
        }
    }
    
    func encodeBytesArrayToBits(bytes:[Byte]) -> [Bit] {
        
        debug("Starting encoding")
        
        //вывод в консоль размера входящих данных в байтах
        debug("Initial bytes count: \(bytes.count)", inConsole: true)
        //создание массива всех битов
        var bits = [Bit]()
        //заполнение массива битами
        bytes.forEach { (byte) in
            bits.append(contentsOf: byte.bits)
        }
        
        //вывод в консоль количества битов
        debug("Initial bits count: \(bits.count)", inConsole: true)
        
        //создание массива продублированных битов
        var doubledBits:[Bit] = []
        
        //для каждого бита в массив добавляются повторения количеством doubleRate
        bits.forEach { (bit) in
            for _ in 0 ..< self.doubleRate {
                doubledBits.append(bit)
            }
        }
        
        //вывод в консоль количества битов после дублирования
        debug("Doubled bits count: \(doubledBits.count)", inConsole: true)
        
        return doubledBits
    }
    
    func encodeDataToBits(data:Data) -> [Bit] {
        return self.encodeBytesArrayToBits(bytes: data.bytes)
    }
    
    func decodeBits(bits:[Bit], completion:@escaping (_ decodedBytes:[Byte]) -> Void) {
        
        self.decodeCompletion = completion
        self.byteIndexesWithErrors = []
        
        var bits = bits
        debug("Decoding bits count: \(bits.count)", inConsole: true)
        
        //проверка на кратность (так как мы увеличили количество битов в три раза, то мы должны убедиться что и закодированное число битов кратно исходному doubleRate)
        if bits.count%self.doubleRate == 0 {
            //счетчик обрабатываемых групп (для наглядности прогресса)
            
            let blocksCount = bits.count/self.doubleRate
            threadsCount = 10
            while blocksCount%threadsCount != 0 {
                if threadsCount > 1 {
                    threadsCount -= 1
                }
            }
            let groupSize = bits.count/threadsCount
            debug("Opening \(threadsCount) threads", inConsole: true)
            
            for i in 0..<threadsCount {
                let bitSubsequence = Array(bits[0..<groupSize])
                
                debug("Started decoding operation \(i)")
                self.decodeBitsSubsequence(bits: bitSubsequence, operatonTag: i) { (operationTag, output, errorIndexes) in
                    self.byteIndexesWithErrors.append(contentsOf: errorIndexes)
                    
                    debug("Ended decoding operation \(operationTag)")
                    self.decodedSubSequences[operationTag] = output //свойство класса
                }
                
                bits.removeSubrange(Range(NSRange(location: 0, length: groupSize))!)
            }
        } else {
            debug("Data corrupted")
            debug("Ended decoding data")
            self.decodeCompletion?([])
        }
    }

    func decodeBitsSubsequence(bits:[Bit], operatonTag:Int, completion:@escaping (_ operationTag:Int, _ output:[Bit], _ errorIndexes:[Int])-> Void) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            var inputBits = bits
            var decodedBits:[Bit] = []
            var errorIndexes:[Int] = []
            
            var counter = 0
            while inputBits.count > 0 {
                //извлечение трёх битов из общего массива битов
                let b = Array(inputBits[0..<self.doubleRate])
                
                //вывод в консоль номера обрабатываемой группы
                //            debug("\(Thread.current)-> Processing group: \(counter)")
                
                var intRep = b[0].rawValue*b[1].rawValue + b[1].rawValue*b[2].rawValue + b[2].rawValue*b[0].rawValue
                //если бит был изначально "1" то формула выдаст на выходе "3"
                //проверяем, если у нас больше "1", то все равно ставим 1
                intRep = intRep > 0 ? 1 : 0
                
                if !(b[0] == b[1] && b[1] == b[2]) {
                    let index = (bits.count/3 * operatonTag + counter)/8
                    if !errorIndexes.contains(index) {
                        errorIndexes.append(index)
                    }
                }
                //добавляем раскодированный бит в итоговый массив раскодированных битов
                if let bit = Bit(rawValue: intRep) {
                    decodedBits.append(bit)
                }
                //удаляем группу обработанных битов из исходного массива
                inputBits.removeSubrange(Range(NSRange(location: 0, length: self.doubleRate))!)
                //инкрементируем счетчик групп
                counter += 1
            }
            
            DispatchQueue.main.async(execute: {
                completion(operatonTag, decodedBits, errorIndexes)
            })
        }
    }

}
