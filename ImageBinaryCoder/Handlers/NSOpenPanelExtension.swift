
import Cocoa

extension NSOpenPanel {
    
    class func selectUrl(withTitle:String, forWindow:NSWindow, imagesOnly:Bool = false, completion:@escaping (_ url:URL?)->Void) {
        let panel = NSOpenPanel()
        panel.prompt = withTitle
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        
        if imagesOnly {
            panel.allowedFileTypes = ["jpg", "jpeg"]
        }
        
        panel.beginSheetModal(for: forWindow) { (response) in
            completion(response.rawValue == NSApplication.ModalResponse.OK.rawValue ? panel.urls.first : nil)
        }
    }
    
}
