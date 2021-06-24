
import Cocoa

class ViewController: NSViewController, NSTextViewDelegate {
    
    @IBOutlet weak var showCorruptedCheckBox: NSButton!
    @IBOutlet weak var originalImageView: NSImageView!
    @IBOutlet weak var grayscaleImageView: NSImageView!
    
    @IBOutlet weak var outputImageView: NSImageView!
    @IBOutlet weak var corruptePixelsImageView: NSImageView!
    
    @IBOutlet weak var openImageButton: NSButton!
    @IBOutlet weak var transmitButton: NSButton!
    @IBOutlet weak var circularIndicator: NSProgressIndicator!
    @IBOutlet weak var percentTextField: NSTextField!
    
    @IBOutlet weak var progressBar: NSProgressIndicator!
    @IBOutlet weak var consoleTextView: NSTextView!
    
    let doubleRate:Int = 3 //количество повторений каждого бита при реализации повторений
    var errorRate:Double = 15 //0...100 %   для примера изначально берем 25
    
    let coder = BitCoder() //объект кодера/декодера
    let binaryChannel = BinaryChannel() //объект симулированного бинарного канала связи
    let imageConverter = ImageConverter()
    
    var originalImage:NSImage?
    var cgGrayscaleImage:CGImage?
    var grayscaleImage:NSImage?
    var imageSize:(width:Int, height:Int) = (0,0)

    override func viewDidLoad() {
        super.viewDidLoad()
        coder.doubleRate = self.doubleRate
        binaryChannel.doubleRate = self.doubleRate
        
        //настраиваем то, как выглядит консоль
        consoleTextView.string = ""
        consoleTextView.textColor = .systemGreen
        
        //для поля с процентом ошибок нам нужно задать форматор, который будет исключать возможность задания букв, нам нужны только числа от 0 до 100
        let formatter = IPNumberFormatter()
        formatter.localizesFormat = false
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2 //2 цифры после запятой (а точнее точки floating point)
        self.percentTextField.formatter = formatter
        
        //Добавляем обработчик на notification об изменении прогресса передачи данных через бинарный канал
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "channel_progress_changed"), object: nil, queue: OperationQueue.main) { (notification) in
            //выставляем сам прогресс
            self.progressBar.doubleValue = self.binaryChannel.progress
            
            //прячем прогресс бар, если прогресс 0 или 100 (операция еще не начата или уже закончена)
            self.progressBar.isHidden = self.binaryChannel.progress == 0 || self.binaryChannel.progress == 100
        }
        
        
        //добавляем обработчик на notification - если нужно что-то записать в консоль приложения
        NotificationCenter.default.addObserver(forName: NSNotification.Name("debug"), object: nil, queue: .main) { (notification) in
            self.consoleTextView.string += "\n" + (notification.userInfo?["message"] as? String ?? "")
        }
    }
    
    func setControlsActive(_ active:Bool) {
        //отключаем или включаем кнопки (отключать нужно во время того, как приложение что-то делает, чтоб не нарушить цикл)
        if active {
            self.circularIndicator.stopAnimation(self)
        } else {
            self.circularIndicator.startAnimation(self)
        }
        self.openImageButton.isEnabled = active
        self.transmitButton.isEnabled = active
    }
    
    @IBAction func pickImageFromFile(_ sender: Any) {
        NSOpenPanel.selectUrl(withTitle: "Choose image", forWindow: self.view.window!, imagesOnly: true) { (choosenFileUrl) in
            if let fileUrl = choosenFileUrl {
                self.originalImage = NSImage(byReferencing: fileUrl)
                
                //convert to grayscale
                let cgImage = self.originalImage!.cgImage(forProposedRect: nil, context: nil, hints: nil)
                self.cgGrayscaleImage = self.imageConverter.convertToGrayScale(image: cgImage!)
                self.grayscaleImage = NSImage(cgImage: self.cgGrayscaleImage!, size: NSZeroSize)
                
                self.originalImageView.image = NSImage(cgImage: cgImage!, size: NSZeroSize)
                self.grayscaleImageView.image = self.grayscaleImage
                
                self.consoleTextView.string = "\(Date.debug()): Image selected"
                
                //очищаем выходные ImageView перед тем как начать новый процесс
                self.outputImageView.image = nil
                self.corruptePixelsImageView.image = nil
            }
        }
    }
    
    @IBAction func toggleShowCorrupted(_ sender: NSButton) {
        self.corruptePixelsImageView.isHidden = sender.state != .on
    }
    
    @IBAction func trasmitDataViaBinaryChannel(_ sender: Any) {
        
        self.setControlsActive(false)
        
        guard self.percentTextField.doubleValue >= 0, self.percentTextField.doubleValue <= 100 else {
            debug("Wrong error percent value!", inConsole: true)
            //допустимы только от нуля до 100 процентов ошибок
            self.setControlsActive(true)
            return
        }
        
        //запоминаем процент ошибок из текстового поля
        self.errorRate = self.percentTextField.doubleValue
        
        guard let grayscaleImage = self.cgGrayscaleImage else {
            //error - no image representation found
            self.setControlsActive(true)
            return
        }
        
        let imageRep = self.imageConverter.pixelValues(fromCGImage: grayscaleImage)
        guard let imageBytes = imageRep.pixelValues else {
            //error - could not convert image to bytes array
            self.setControlsActive(true)
            return
        }
        
        debug("Starting opertation...", inConsole: true)
        
        //запоминаем размер изображения для будущей декодировки изображения из массива пиксельных значений
        self.imageSize = (imageRep.width, imageRep.height)
        debug("Image size (px):\(self.imageSize)", inConsole: true)
        
        debug("Starting encoding", inConsole: true)
        //кодируем и дублируем данные
        let bitsData = coder.encodeBytesArrayToBits(bytes: imageBytes)
        
        debug("Initiating data transfer", inConsole: true)
        //симулируем передачу по бинарному каналу массива битов, передавая параметром errorRate - процент внедрения ошибок
        binaryChannel.simulateTransferOf(bitsArray: bitsData, usingErrorRate: errorRate) { (rcvdBits) in
            
            //на выходе симуляции мы получаем массив битов тоже с повторениями, но уже с внедренными ошибками - rcvdBits
            
            debug("Ended data transfer", inConsole: true)
            
            debug("Started bytes decoding", inConsole: true)
            //декодируем данные
            self.coder.decodeBits(bits: rcvdBits) { (decodedBytes) in
                
                debug("Finished bytes decoding", inConsole: true)
                
                if decodedBytes.count == 0 {
                    debug("ERROR DECODING")
                    self.setControlsActive(true)
                    return
                }
                
                debug("Starting image generation", inConsole: true)
                //генерируем изображение, полученное на выходе из бинарного канала после исправления ошибок
                let imageOutput = self.imageConverter.imageFromPixelValues(pixelValues: decodedBytes, width: self.imageSize.width, height: self.imageSize.height)
                if imageOutput != nil {
                    self.outputImageView.image = NSImage(cgImage: imageOutput!, size: NSZeroSize)
                } else {
                    print("Error with NSImage convert")
                }
                
                //генерируем изображение, на котором будут закрашены ошибочные пиксели красным цветом
                
                //для начала создаем массив пустых прозрачных пикселей (все компоненты будут у нас 0x0)
                var corruption = [UInt8](repeating: 0x0, count: decodedBytes.count*4) //умножаем на 4, так как RGBA имеет 4 канала (включая альфу)
                
                //получаем индексы пикселей в которых были ошибки
                let corruptedIndexes = self.coder.byteIndexesWithErrors.compactMap({$0*4}) //каждый ошибочный индекс умножаем так же на 4
                
                //в созданном пустом прозрачном массиве заменяем пиксели красным цветом по индексам с ошибками
                corruptedIndexes.forEach({
                    corruption[$0] = 0xFF //выставляем красный компонент на максимум
                    //компоненты зеленого и синего игнорируем
                    corruption[$0 + 3] = 0xFF //выставляем альфу на максимум ( + 3 поотму что alpha идет как четвертый компонент в RGBA)
                }) //в итоге получается для каждого пикселя выстраивается такая структура 0xFF 0x0 0x0 0xFF (0xRR GG BB AA)
                
                //генерируем само 32-битное изображение RGBA - Red Greeb Blue Alpha - на каждый компонент по 1 байту = 8 * 4 = 32 бита
                let imageCurruption = self.imageConverter.imageRGBA(fromPixelValues: corruption, width: self.imageSize.width, height: self.imageSize.height)
                if imageCurruption != nil {
                    self.corruptePixelsImageView.image = NSImage(cgImage: imageCurruption!, size: NSZeroSize)
                } else {
                    print("Error with NSImage convert")
                }
                debug("Operation successfully completed", inConsole: true)
                self.setControlsActive(true)
            }
        }
    }
}

//если выставлен флаг inConsole - будет выслать notification, который запишет сообщение в UI консоль самого приложения (по дефолту - стоит false, то есть в консоль приложения ничего не выводится)
func debug(_ message:String, inConsole:Bool = false) {
    let msg = "\(Date.debug()):\(message)"
    if inConsole {
        NotificationCenter.default.post(name: NSNotification.Name("debug"), object: nil, userInfo: ["message":msg])
    }
    print(msg)
}

//это для логов
extension Date {
    static func debug() -> String {
        let d = Date()
        let df = DateFormatter()
        df.dateFormat = "y-MM-dd H:m:ss.SSSS"
        return df.string(from: d)
    }
}


