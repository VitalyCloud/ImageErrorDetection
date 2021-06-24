
import Cocoa

class BinaryChannel: NSObject {
    
    var doubleRate:Int = 3
    var progress:Double = 0.0 {
        didSet {
            NotificationCenter.default.post(Notification(name: Notification.Name("channel_progress_changed")))
        }
    }
    
    func simulateTransferOf(bitsArray:[Bit], usingErrorRate:Double, onTransferComplete:@escaping (_ receivedBits:[Bit])->Void) {
        
        var inputBits = bitsArray
        
        //определяем изначальное кол-во байтов
        let initialBytesCount = (bitsArray.count/8)/doubleRate
        
        //определяем максимальное число возможных ошибок
        let errorsMaxCount = Int((Double(initialBytesCount) * (usingErrorRate/100.0)).rounded(.toNearestOrEven))
        
        //определяем длину суб-последовательности (эквивалент 1 байту в исходных данных)
        let subsequenceSize = self.doubleRate*8
        
        //счетчик внедренных ошибок
        var errorsInjected = 0
        
        //создаем массив индексов, в которых будут инжектиться ошибки
        var indexes:[Int] = self.uniqueRandoms(numberOfRandoms: errorsMaxCount, minNum: 0, maxNum: UInt32(initialBytesCount))
        
        //запускаем блок в параллельном потоке с высшим приоритетом - userInitiated
        //бинарный канал в данном случае будет выполнен параллельно, не загружая главный поток
        DispatchQueue.global(qos: .userInitiated).async {
            
            
            for i in 0..<indexes.count-1 {
                
                //берем индекс из массива
                let index = indexes[i]
                
                //умножаем на длинну суб-последовательности, чтоб получить стартовый индекс бита
                let startIndex = index * subsequenceSize
                //определяем диапазон, в котором находиится наша суб-последовательность битов
                let bitsRange = startIndex..<startIndex + subsequenceSize
                //выбираем нашу суб-последовательность
                var bits = Array(inputBits[bitsRange])
                
                //если кол-во ошибок еще не достигло максимума
                if errorsInjected < errorsMaxCount {
                    //выбираем рандомный индекс бита в кортеже из 3 битов
                    let errorInjectionIndex = Int.random(in: 0..<subsequenceSize)
                    //выбираем бит в полученном индексе
                    let bit = bits[errorInjectionIndex]
                    //ставим значение бита в противоположное значение
                    bits[errorInjectionIndex] = bit.invert()
                    //увеличиваем счетчик внедренных ошибок
                    errorsInjected += 1
                }
                
                //заменаем в основной последовательности суб-последовательность на новую
                inputBits.replaceSubrange(bitsRange, with: bits)
                
                
                self.progress = Double(i)/Double(indexes.count)*100.0
            }
            
            self.progress = 100.0
            
            //когда операция в параллельном потоке завершит свое выполнение - вызывается блок в главном потоке - main
            DispatchQueue.main.async(execute: {
                debug("\(errorsInjected) errors injected in \(initialBytesCount) bytes", inConsole: true)
                onTransferComplete(inputBits)
            })
        }
    }
    
    func uniqueRandoms(numberOfRandoms: Int, minNum: Int, maxNum: UInt32) -> [Int] {
        var uniqueNumbers = Set<Int>()
        while uniqueNumbers.count < numberOfRandoms {
            uniqueNumbers.insert(Int(arc4random_uniform(maxNum + 1)) + minNum)
        }
        return Array(uniqueNumbers).sorted(by: {$0 < $1})
    }
}


