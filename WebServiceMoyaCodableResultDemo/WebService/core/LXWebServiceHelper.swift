

import Foundation
import Moya
import Combine

typealias ResultContainer<T: Codable> = Result<LXResponseContainer<T>, Error>

open class LXWebServiceHelper<T> where T: Codable {
    typealias JSONObjectHandle = (Any) -> Void
    typealias ExceptionHandle = (Error?) -> Void
    typealias ResultContainerHandle = (ResultContainer<T>) -> Void
    
    typealias AutoLogOutHandler = () -> Void
    /// bool 返回是否需要自动处理
    typealias ToastHandler = (LXError) -> (autoShow: Bool, type: ToastType)
    
    var autoLogoutHandler: AutoLogOutHandler?
    var toastHandler: ToastHandler?
    
    init() {
        self.toastHandler = { error in
            return (autoShow: true, type: .toast)
        }
    }
    
    @discardableResult
    func requestJSONModel<R: LXMoyaTargetType>(_ type: R,
                                               progressBlock: ProgressBlock? = nil,
                                               completionHandle: @escaping ResultContainerHandle) -> Moya.Cancellable? {
        return requestJSONObject(type, progressBlock: progressBlock) { [weak self] result in
            let result: ResultContainer<T> = parseResponseToResult(responseObject: result, error: nil)
            switch result {
            case .success( _):
                break
            case .failure(let error):
                self?.handleError(error)
            }
            completionHandle(result)
        } exceptionHandle: { [weak self] error in
            let result: ResultContainer<T> = parseResponseToResult(responseObject: nil, error: error)
            self?.handleError(error)
            completionHandle(result)
        }
    }
    
    // 可自定义加解密插件等
    private func createProvider<R: LXMoyaTargetType>(type: R) -> MoyaProvider<R> {
        let activityPlugin = NetworkActivityPlugin { state, targetType in
            self.networkActiviyIndicatorVisible(visibile: state == .began)
        }
        
        //        let aesPlugin = LXHandleRequestPlugin()
        
        let crePlugin = type.credentials
        
        var plugins = [PluginType]()
        plugins.append(activityPlugin)
        
        if crePlugin != nil {
            plugins.append(crePlugin!)
        }
        
#if DEBUG
        plugins.append(HighPrecisionTimingPlugin())
        plugins.append(NetworkLoggerPlugin(configuration: .init(logOptions: [.requestHeaders, .requestBody, .successResponseBody])))
#else
#endif
//        let requestTimeoutClosure = { (endpoint: Endpoint, done: @escaping MoyaProvider<R>.RequestResultClosure) in
//            do {
//                var request = try endpoint.urlRequest()
//                request.timeoutInterval = 30
//                done(.success(request))
//            } catch {
//                done(.failure(MoyaError.underlying(error, nil)))
//            }
//        }
        
        
        // 包含token刷新
//        let requestClorure = MoyaProvider<R>.endpointResolver()
//        
//        let provider = MoyaProvider<R>(requestClosure: requestClorure, plugins: plugins)
        
        // 不包含token刷新
        let provider = MoyaProvider<R>(plugins: plugins)
        
        return provider
    }
    
    private func networkActiviyIndicatorVisible(visibile: Bool) {
        if #available(iOS 13, *) {
            
        } else {
            UIApplication.shared.isNetworkActivityIndicatorVisible = visibile
        }
    }
    
    @discardableResult
    private func requestJSONObject<R: LXMoyaTargetType>(_ type: R,
                                                progressBlock: ProgressBlock?,
                                                completionHandle: @escaping JSONObjectHandle,
                                                        exceptionHandle: @escaping (Error?) -> Void) -> Moya.Cancellable? {
        
        if !NetworkMonitor.default.isConnected {
            exceptionHandle(LXError.networkConnectFailed)
            return nil
        }
        
        let provider = createProvider(type: type)
        let cancelable = provider.request(type, callbackQueue: nil, progress: progressBlock) { result in
            switch result {
            case .success(let successResponse):
                do {
                    
                    let jsonObject = try successResponse.mapJSON()
                    
//#if DEBUG
//if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
//   let jsonString = String(data: jsonData, encoding: .utf8) {
//    printl(message: "response jsonString: \(jsonString)")
//}
//#else
//#endif
                    
                    completionHandle(jsonObject)
                } catch  {
                    exceptionHandle(LXError.serverDataFormatError)
                }
                break
            case .failure(let error):
                if error.errorCode == NSURLErrorTimedOut {
                    exceptionHandle(LXError.networkConnectTimeOut)
                } else {
                    exceptionHandle(LXError.networkConnectFailed)
                }
                break
            }
        }
        return cancelable
    }
}

extension LXWebServiceHelper {
    fileprivate func handleError(_ error: Error?) {
        ErrorHandle.handleError(error, autoLogoutHandler: autoLogoutHandler, toastHandler: toastHandler)
    }
}



// MARK: - combine支持, 注意下面两种写法的不同
extension LXWebServiceHelper {
    
//    func requestJsonModelPublisher<R: LXMoyaTargetType>(_ type: R,
//                                                        progressBlock: ProgressBlock?) -> AnyPublisher<LXResponseContainer<T>, Error> {
//        return Future<LXResponseContainer<T>, Error> { promise in
//            self.requestJSONObject(type, progressBlock: progressBlock) { response in
//                let result: ResultContainer<T> = parseResponseToResult(responseObject: response, error: nil)
//                switch result {
//                case .success(let container):
//                    promise(.success(container))
//                case .failure(let error):
//                    promise(.failure(error))
//                }
//            } exceptionHandle: { error in
//                let result: ResultContainer<T> = parseResponseToResult(responseObject: nil, error: error)
//                switch result {
//                case .success(let container):
//                    promise(.success(container))
//                case .failure(let error):
//                    promise(.failure(error))
//                }
//            }
//        }.eraseToAnyPublisher()
//    }
    
    /// progress暂时不可用
    func requestJsonModelPublisher<R: LXMoyaTargetType>(_ type: R,
                                                        progressBlock: ProgressBlock?) -> AnyPublisher<ResultContainer<T>, Never> {
        return Future<ResultContainer<T>, Never> { promise in
            self.requestJSONModel(type, progressBlock: progressBlock) { result in
                promise(.success(result))
            }
        }.eraseToAnyPublisher()
    }
}
