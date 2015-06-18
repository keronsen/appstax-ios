
import Foundation

// TODO: Make internal
@objc public class AXApiClient: NSObject {
    
    public private(set) var sessionID: String?
    var baseUrl: String
    var appKey: String
    var urlSession: NSURLSession
    
    public func updateSessionID(id: String?) {
        sessionID = id
    }
    
    public init(appKey: String, baseUrl: String) {
        self.appKey = appKey
        self.baseUrl = baseUrl
        self.sessionID = nil
        self.urlSession = NSURLSession.sharedSession()
    }
    
    public func postDictionary(dictionary: [String:AnyObject], toUrl: NSURL, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        sendHttpBody(serializeDictionary(dictionary), toUrl: toUrl, method: "POST", headers: [:]) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func putDictionary(dictionary: [String:AnyObject], toUrl: NSURL, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        sendHttpBody(serializeDictionary(dictionary), toUrl: toUrl, method: "PUT", headers: [:]) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func sendMultipartFormData(dataParts: [String:AnyObject], toUrl: NSURL, method: String, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        var boundary = "Boundary-\(NSUUID().UUIDString)"
        var contentType = "multipart/form-data; boundary=\(boundary)"
        var body = NSMutableData()
        
        for (partName, part) in dataParts {
            var filename = part["filename"] as! String? ?? ""
            var mimeType = part["mimeType"] as! String? ?? ""
            var data = part["data"] as! NSData
            body.appendData(stringData("--\(boundary)\r\n"))
            if filename != "" {
                body.appendData(stringData("Content-Disposition: form-data; name=\"\(partName)\"; filename=\"\(filename)\"\r\n"))
            } else {
                body.appendData(stringData("Content-Disposition: form-data; name=\"\(partName)\r\n"))
            }
            if mimeType != "" {
                body.appendData(stringData("Content-Type: \(mimeType)\r\n"))
            }
            body.appendData(stringData("\r\n"))
            body.appendData(data)
            body.appendData(stringData("\r\n"))
        }
        body.appendData(stringData("--\(boundary)--\r\n"))
        
        sendHttpBody(body, toUrl: toUrl, method: method, headers: ["Content-Type":contentType]) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func dictionaryFromUrl(url: NSURL, completion: (([String:AnyObject]?, NSError?) -> ())?) {
        dataFromUrl(url) {
            completion?(self.deserializeDictionary($0), $1)
        }
    }
    
    public func arrayFromUrl(url: NSURL, completion: (([AnyObject]?, NSError?) -> ())?) {
        dataFromUrl(url) {
            completion?(self.deserializeArray($0), $1)
        }
    }
    
    public func dataFromUrl(url: NSURL, completion: ((NSData?, NSError?) -> ())?) {
        let request = makeRequestWithMethod("GET", url: url, headers: [:])
        logRequest(request)
        urlSession.dataTaskWithRequest(request) {
            var data = $0
            var response = $1
            var error = $2
            
            self.logResponse(response, data: data, error: error)
            if error == nil {
                error = self.errorFromResponse(response, data: data)
            }
            if error != nil {
                data = nil
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion?(data, error);
            }
        }.resume()
    }
    
    public func deleteUrl(url: NSURL, completion: ((NSError?) -> ())?) {
        sendHttpBody(NSData(), toUrl: url, method: "DELETE", headers: [:]) {
            completion?($1)
        }
    }
    
    public func urlByConcatenatingStrings(strings: [String]) -> NSURL? {
        let full = baseUrl.stringByAppendingString("".join(strings))
        return NSURL(string: full)
    }
    
    public func urlFromTemplate(template: String, parameters: [String:String], queryParameters: [String:String] = [:]) -> NSURL? {
        let url = NSMutableString(string: template)
        if(url.hasPrefix("/")) {
            url.replaceCharactersInRange(NSMakeRange(0, 1), withString: "")
        }
        url.insertString(baseUrl, atIndex: 0)
        for (key, value) in parameters {
            url.replaceOccurrencesOfString(":" + key, withString: urlEncode(value), options: .LiteralSearch, range: NSMakeRange(0, url.length))
        }
        
        var queryString = ""
        if queryParameters.count > 0 {
            queryString = "&".join(queryParameters.keys.array.map({
                key in
                if let value = queryParameters[key] {
                    return "\(key)=\(self.urlEncode(value))"
                }
                return ""
            }))
            var queryStringPrefix = (url.rangeOfString("?").toRange() == nil) ? "?" : "&"
            queryString = "\(queryStringPrefix)\(queryString)"
        }
        
        let full: String = url.stringByAppendingString(queryString)
        return NSURL(string: full)
    }
    
    public func deserializeDictionary(data: NSData?) -> [String:AnyObject]? {
        if data == nil {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(0), error: nil) as? [String:AnyObject]
    }
    
    public func deserializeArray(data: NSData?) -> [AnyObject]? {
        if data == nil {
            return nil
        }
        return NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions(0), error: nil) as? [AnyObject]
    }
    
    public func serializeDictionary(dictionary: [String:AnyObject]?) -> NSData {
        if dictionary == nil {
            return NSData()
        }
        let data = NSJSONSerialization.dataWithJSONObject(dictionary!, options: NSJSONWritingOptions(0), error: nil)
        if data == nil {
            return NSData()
        }
        return data!
    }
    
    public func urlEncode(string: String) -> String {
        let encoded = NSMutableString()
        encoded.setString(string.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!)
        
        let pairs = ["'":"%27",
            "=":"%3D"]
        
        for (key, value) in pairs {
            encoded.replaceOccurrencesOfString(key, withString: value, options: .LiteralSearch, range: NSMakeRange(0, encoded.length))
        }
        
        return encoded as String
    }
    
    
    // PRIVATE
    
    private func sendHttpBody(httpBody: NSData, toUrl: NSURL, method: String, headers: [String:String], completion: (NSData?, NSError?) -> ()) {
        let request = makeRequestWithMethod(method, url: toUrl, headers: headers)
        request.HTTPBody = httpBody
        NSURLProtocol.setProperty(request.HTTPBody!, forKey: "HTTPBody", inRequest: request)
        urlSession.uploadTaskWithRequest(request, fromData: nil) {
            var data = $0
            var response = $1
            var error = $2
            
            self.logResponse(response, data: data, error: error)
            if error == nil {
                error = self.errorFromResponse(response, data: data)
            }
            if error != nil {
                data = nil
            }
            dispatch_async(dispatch_get_main_queue()) {
                completion(data, error);
            }
        }.resume()
    }
    
    private func makeRequestWithMethod(method: String, url: NSURL, headers: [String:String]) -> NSMutableURLRequest {
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = method
        request.setValue(appKey, forHTTPHeaderField: "x-appstax-appkey")
        request.setValue(sessionID, forHTTPHeaderField: "x-appstax-sessionid")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
    
    func logRequest(request: NSURLRequest) {
        
    }
    
    func logResponse(response: NSURLResponse?, data: NSData?, var error: NSError?) {
        if error != nil && response != nil {
            error = errorFromResponse(response!, data: data)
        }
    }
    
    func errorFromResponse(response: NSURLResponse, data: NSData?) -> NSError? {
        let httpResponse = response as! NSHTTPURLResponse
        var error: NSError?
        if httpResponse.statusCode / 100 != 2 {
            let message: String = deserializeDictionary(data)?["errorMessage"] as? String ?? ""
            error = NSError(domain: "ApiClientHttpError", code: httpResponse.statusCode, userInfo: ["errorMessage": message])
        }
        return error
    }
    
    func stringData(string: String) -> NSData {
        return string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
    }
    
}