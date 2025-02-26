//
//  LXResponseContainer.swift
//  WebServiceMoyaCodableResultDemo
//
//  Created by mac on 2024/10/14.
//

import Foundation

/// 后端返回的code
public struct ResponseCode {
    static let successResponseStatusCode = 200
}

/// 需要根据实际情况修改，这个只是demo请求使用
struct LXResponseContainer<T: Codable> {
//    let success: Bool
    /// 元数据
    let rawObject: Any?
    let code: Int?
    let message: String?
    let value: T?
}

/// 如果data返回的空数组，T 传 [String] 里面任意类型都可以，一般用于不需要返回值，但是data又是空数组的情况
func parseResponseToResult<T: Codable>(responseObject: Any?, error: Error?) -> ResultContainer<T> {
    
//    let test = ["message": "success感谢又拍云(upyun.com)提供CDN赞助", "status":200,"date":"20241101","time":"2024-11-01 09:08:51","cityInfo":[]] as [String : Any]
    
    /// 有错误就直接返回
    if let error = error {
        return .failure(error)
    }
    /// 检查数据完整性，根据自己项目实际情况进行修改
    guard let jsonObject = responseObject as? [String: Any],
          let statusCode = jsonObject[ServerKey.code.rawValue] as? Int, /*,
          let success = jsonObject[ServerKey.success.rawValue] as? Bool,*/
          let message = jsonObject[ServerKey.message.rawValue] as? String else {
        return .failure(LXError.serverDataFormatError)
    }
    
    /// 检查value数据是否存在
    guard let jsonValue = jsonObject[ServerKey.value.rawValue] else {
        return .failure(LXError.missDataContent)
    }
    
    if statusCode == ResponseCode.successResponseStatusCode {
        // 对烂后端的兼容，一般不需要
//        guard let jsonValue = jsonObject[ServerKey.value.rawValue], !(jsonValue is NSNull) else {
//            return .success(LXResponseContainer(rawObject: nil,
//                                                code: statusCode,
//                                                message: message,
//                                                value: nil))
//        }
//        
//        if let tempArray = jsonValue as? Array<Any>, tempArray.isEmpty {
//            return .success(LXResponseContainer(rawObject: nil,
//                                                code: statusCode,
//                                                message: message,
//                                                value: [] as? T))
//        }
        
        // 如果data就是结果，直接赋值
        if let dataObject = jsonValue as? T {
            return .success(LXResponseContainer(rawObject: jsonValue,
                                                code: statusCode,
                                                message: message,
                                                value: dataObject))
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonValue, options: .prettyPrinted) else {
            return .failure(LXError.jsonSerializationFailed(message: "json data 解析失败"))
        }
        
        do {
            let model = try JSONDecoder().decode(T.self, from: jsonData)
            return .success(LXResponseContainer(
                                                rawObject: jsonValue,
                                                code: statusCode,
                                                message: message,
                                                value: model))
        } catch DecodingError.keyNotFound(let key, let context) {
            printl(message: "keyNotFound: \(key) is not found in JSON: \(context.debugDescription)")
            return .failure(LXError.dataContentTransformToModelFailed)
        } catch DecodingError.valueNotFound(let type, let context) {
            printl(message: "valueNotFound: \(type) is not found in JSON: \(context.debugDescription)")
            return .failure(LXError.dataContentTransformToModelFailed)
        } catch DecodingError.typeMismatch(let type, let context) {
            printl(message: "typeMismatch: \(type) is mismatch in JSON: \(context.debugDescription) \(context.codingPath)")
            return .failure(LXError.dataContentTransformToModelFailed)
        } catch DecodingError.dataCorrupted(let context) {
            printl(message: "dataCorrupted: \(context.debugDescription)")
            return .failure(LXError.dataContentTransformToModelFailed)
        } catch let error {
            printl(message: "error: \(error.localizedDescription)")
            return .failure(LXError.exception(message: error.localizedDescription))
        }
    } else {
        return .failure(LXError.serverResponseError(message: message, code: "\(statusCode)"))
    }
}
