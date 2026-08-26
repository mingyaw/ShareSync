import Foundation

enum LocalNetworkURLSessionFactory {
    static func shortRequestSession() -> URLSession {
        URLSession(configuration: shortRequestConfiguration())
    }

    static func mediaTransferSession() -> URLSession {
        URLSession(configuration: mediaTransferConfiguration())
    }

    static func shortRequestConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 20
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return configuration
    }

    static func mediaTransferConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 600
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return configuration
    }
}
