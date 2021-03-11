//
//  Copyright © 2019 Iterable. All rights reserved.
//

import Foundation
import UIKit

/// This is a stateless pure functional class
/// This will create IterableRequest
/// The API Endpoint and request endpoint is not defined yet
struct RequestCreator {
    let apiKey: String
    let auth: Auth
    let deviceMetadata: DeviceMetadata
    
    // MARK: - API REQUEST CALLS
    
    func createUpdateEmailRequest(newEmail: String) -> Result<IterableRequest, IterableError> {
        var body: [String: Any] = [JsonKey.newEmail: newEmail]
        
        if let email = auth.email {
            body[JsonKey.currentEmail] = email
        } else if let userId = auth.userId {
            body[JsonKey.currentUserId] = userId
        } else {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }
        
        return .success(.post(createPostRequest(path: Const.Path.updateEmail, body: body)))
    }
    
    func createRegisterTokenRequest(registerTokenInfo: RegisterTokenInfo,
                                    notificationsEnabled: Bool) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        let dataFields = DataFieldsHelper.createDataFields(sdkVersion: registerTokenInfo.sdkVersion,
                                                           deviceId: registerTokenInfo.deviceId,
                                                           device: UIDevice.current,
                                                           bundle: Bundle.main,
                                                           notificationsEnabled: notificationsEnabled,
                                                           deviceAttributes: registerTokenInfo.deviceAttributes)
        
        let deviceDictionary: [String: Any] = [
            JsonKey.token: registerTokenInfo.hexToken,
            JsonKey.platform: RequestCreator.pushServicePlatformToString(registerTokenInfo.pushServicePlatform,
                                                                                 apnsType: registerTokenInfo.apnsType),
            JsonKey.applicationName: registerTokenInfo.appName,
            JsonKey.dataFields: dataFields,
        ]
        
        var body = [AnyHashable: Any]()
        
        body[JsonKey.device] = deviceDictionary
        
        setCurrentUser(inDict: &body)
        
        if auth.email == nil, auth.userId != nil {
            body[JsonKey.preferUserId] = true
        }
        
        return .success(.post(createPostRequest(path: Const.Path.registerDeviceToken, body: body)))
    }
    
    func createUpdateUserRequest(dataFields: [AnyHashable: Any], mergeNestedObjects: Bool) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body[JsonKey.dataFields] = dataFields
        body[JsonKey.mergeNestedObjects] = NSNumber(value: mergeNestedObjects)
        setCurrentUser(inDict: &body)
        
        if auth.email == nil, auth.userId != nil {
            body[JsonKey.preferUserId] = true
        }
        
        return .success(.post(createPostRequest(path: Const.Path.updateUser, body: body)))
    }
    
    func createTrackPurchaseRequest(_ total: NSNumber, items: [CommerceItem], dataFields: [AnyHashable: Any]?) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var itemsToSerialize = [[AnyHashable: Any]]()
        
        for item in items {
            itemsToSerialize.append(item.toDictionary())
        }
        
        var apiUserDict = [AnyHashable: Any]()
        
        setCurrentUser(inDict: &apiUserDict)
        
        var body: [String: Any] = [JsonKey.Commerce.user: apiUserDict,
                                   JsonKey.Commerce.items: itemsToSerialize,
                                   JsonKey.Commerce.total: total]
        
        if let dataFields = dataFields {
            body[JsonKey.dataFields] = dataFields
        }
        
        return .success(.post(createPostRequest(path: Const.Path.trackPurchase, body: body)))
    }
    
    func createTrackPushOpenRequest(_ campaignId: NSNumber, templateId: NSNumber?, messageId: String, appAlreadyRunning: Bool, dataFields: [AnyHashable: Any]?) -> Result<IterableRequest, IterableError> {
        var body = [AnyHashable: Any]()
        var reqDataFields = [AnyHashable: Any]()
        
        if let dataFields = dataFields {
            reqDataFields = dataFields
        }
        
        reqDataFields[JsonKey.appAlreadyRunning] = appAlreadyRunning
        body[JsonKey.dataFields] = reqDataFields
        
        setCurrentUser(inDict: &body)
        
        body[JsonKey.campaignId] = campaignId
        
        if let templateId = templateId {
            body[JsonKey.templateId] = templateId
        }
        
        body.setValue(for: JsonKey.messageId, value: messageId)
        
        return .success(.post(createPostRequest(path: Const.Path.trackPushOpen, body: body)))
    }
    
    func createTrackEventRequest(_ eventName: String, dataFields: [AnyHashable: Any]?) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        setCurrentUser(inDict: &body)

        body.setValue(for: JsonKey.eventName, value: eventName)
        
        if let dataFields = dataFields {
            body[JsonKey.dataFields] = dataFields
        }
        
        return .success(.post(createPostRequest(path: Const.Path.trackEvent, body: body)))
    }
    
    func createUpdateSubscriptionsRequest(_ emailListIds: [NSNumber]? = nil,
                                          unsubscribedChannelIds: [NSNumber]? = nil,
                                          unsubscribedMessageTypeIds: [NSNumber]? = nil,
                                          subscribedMessageTypeIds: [NSNumber]? = nil,
                                          campaignId: NSNumber? = nil,
                                          templateId: NSNumber? = nil) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        setCurrentUser(inDict: &body)
        
        if let emailListIds = emailListIds {
            body[JsonKey.emailListIds] = emailListIds
        }
        
        if let unsubscribedChannelIds = unsubscribedChannelIds {
            body[JsonKey.unsubscribedChannelIds] = unsubscribedChannelIds
        }
        
        if let unsubscribedMessageTypeIds = unsubscribedMessageTypeIds {
            body[JsonKey.unsubscribedMessageTypeIds] = unsubscribedMessageTypeIds
        }
        
        if let subscribedMessageTypeIds = subscribedMessageTypeIds {
            body[JsonKey.subscribedMessageTypeIds] = subscribedMessageTypeIds
        }
        
        if let campaignId = campaignId?.intValue {
            body[JsonKey.campaignId] = campaignId
        }
        
        if let templateId = templateId?.intValue {
            body[JsonKey.templateId] = templateId
        }
        
        return .success(.post(createPostRequest(path: Const.Path.updateSubscriptions, body: body)))
    }
    
    func createGetInAppMessagesRequest(_ count: NSNumber) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var args: [AnyHashable: Any] = [JsonKey.InApp.count: count.description,
                                        JsonKey.platform: JsonValue.iOS.jsonStringValue,
                                        JsonKey.systemVersion: UIDevice.current.systemVersion,
                                        JsonKey.InApp.sdkVersion: IterableAPI.sdkVersion]
        
        if let packageName = Bundle.main.appPackageName {
            args[JsonKey.InApp.packageName] = packageName
        }
        
        setCurrentUser(inDict: &args)
        
        return .success(.get(createGetRequest(forPath: Const.Path.getInAppMessages, withArgs: args as! [String: String])))
    }
    
    func createTrackInAppOpenRequest(inAppMessageContext: InAppMessageContext) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: inAppMessageContext.messageId)
        
        setCurrentUser(inDict: &body)
        
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        if let inboxSessionId = inAppMessageContext.inboxSessionId {
            body.setValue(for: JsonKey.inboxSessionId, value: inboxSessionId)
        }
        
        return .success(.post(createPostRequest(path: Const.Path.trackInAppOpen, body: body)))
    }
    
    func createTrackInAppClickRequest(inAppMessageContext: InAppMessageContext, clickedUrl: String) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: inAppMessageContext.messageId)
        
        setCurrentUser(inDict: &body)
        
        body.setValue(for: JsonKey.clickedUrl, value: clickedUrl)
        
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        if let inboxSessionId = inAppMessageContext.inboxSessionId {
            body.setValue(for: JsonKey.inboxSessionId, value: inboxSessionId)
        }
        
        return .success(.post(createPostRequest(path: Const.Path.trackInAppClick, body: body)))
    }
    
    func createTrackInAppCloseRequest(inAppMessageContext: InAppMessageContext, source: InAppCloseSource?, clickedUrl: String?) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: inAppMessageContext.messageId)
        
        if let source = source {
            body.setValue(for: JsonKey.closeAction, value: source)
        }
        
        if let clickedUrl = clickedUrl {
            body.setValue(for: JsonKey.clickedUrl, value: clickedUrl)
        }
        
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        if let inboxSessionId = inAppMessageContext.inboxSessionId {
            body.setValue(for: JsonKey.inboxSessionId, value: inboxSessionId)
        }
        
        setCurrentUser(inDict: &body)
        
        return .success(.post(createPostRequest(path: Const.Path.trackInAppClose, body: body)))
    }
    
    func createTrackInAppDeliveryRequest(inAppMessageContext: InAppMessageContext) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: inAppMessageContext.messageId)
        
        setCurrentUser(inDict: &body)
        
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        return .success(.post(createPostRequest(path: Const.Path.trackInAppDelivery, body: body)))
    }
    
    func createInAppConsumeRequest(_ messageId: String) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: messageId)
        
        setCurrentUser(inDict: &body)
        
        return .success(.post(createPostRequest(path: Const.Path.inAppConsume, body: body)))
    }
    
    func createTrackInAppConsumeRequest(inAppMessageContext: InAppMessageContext, source: InAppDeleteSource?) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: inAppMessageContext.messageId)
        
        if let source = source {
            body.setValue(for: JsonKey.deleteAction, value: source)
        }
        
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        if let inboxSessionId = inAppMessageContext.inboxSessionId {
            body.setValue(for: JsonKey.inboxSessionId, value: inboxSessionId)
        }
        
        setCurrentUser(inDict: &body)
        
        return .success(.post(createPostRequest(path: Const.Path.inAppConsume, body: body)))
    }
    
    func createTrackInboxSessionRequest(inboxSession: IterableInboxSession) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        guard let inboxSessionId = inboxSession.id else {
            return .failure(IterableError.general(description: "expecting session UUID"))
        }
        
        guard let sessionStartTime = inboxSession.sessionStartTime else {
            return .failure(IterableError.general(description: "expecting session start time"))
        }
        
        guard let sessionEndTime = inboxSession.sessionEndTime else {
            return .failure(IterableError.general(description: "expecting session end time"))
        }
        
        var body = [AnyHashable: Any]()

        setCurrentUser(inDict: &body)
        
        body.setValue(for: JsonKey.inboxSessionId, value: inboxSessionId)
        body.setValue(for: JsonKey.inboxSessionStart, value: IterableUtil.int(fromDate: sessionStartTime))
        body.setValue(for: JsonKey.inboxSessionEnd, value: IterableUtil.int(fromDate: sessionEndTime))
        body.setValue(for: JsonKey.startTotalMessageCount, value: inboxSession.startTotalMessageCount)
        body.setValue(for: JsonKey.endTotalMessageCount, value: inboxSession.endTotalMessageCount)
        body.setValue(for: JsonKey.startUnreadMessageCount, value: inboxSession.startUnreadMessageCount)
        body.setValue(for: JsonKey.endUnreadMessageCount, value: inboxSession.endUnreadMessageCount)
        body.setValue(for: JsonKey.impressions, value: inboxSession.impressions.compactMap { $0.asDictionary() })
        
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        return .success(.post(createPostRequest(path: Const.Path.trackInboxSession, body: body)))
    }
    
    func createDisableDeviceRequest(forAllUsers allUsers: Bool, hexToken: String) -> Result<IterableRequest, IterableError> {
        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.token, value: hexToken)
        
        if !allUsers {
            setCurrentUser(inDict: &body)
        }
        
        return .success(.post(createPostRequest(path: Const.Path.disableDevice, body: body)))
    }
    
    func createGetRemoteConfigurationRequest() -> Result<IterableRequest, IterableError> {
        var args: [AnyHashable: Any] = [JsonKey.platform: JsonValue.iOS.jsonStringValue,
                                        JsonKey.systemVersion: UIDevice.current.systemVersion,
                                        JsonKey.InApp.sdkVersion: IterableAPI.sdkVersion]
        
        if let packageName = Bundle.main.appPackageName {
            args[JsonKey.InApp.packageName] = packageName
        }

        return .success(.get(createGetRequest(forPath: Const.Path.getRemoteConfiguration, withArgs: args as! [String: String])))
    }
    
    // MARK: - PRIVATE
    
    private func createPostRequest(path: String, body: [AnyHashable: Any]? = nil) -> PostRequest {
        PostRequest(path: path,
                    args: [JsonKey.Header.apiKey: apiKey],
                    body: body)
    }
    
    private func createGetRequest(forPath path: String, withArgs args: [String: String]) -> GetRequest {
        GetRequest(path: path,
                   args: args)
    }
    
    private static func pushServicePlatformToString(_ pushServicePlatform: PushServicePlatform, apnsType: APNSType) -> String {
        switch pushServicePlatform {
        case .production:
            return JsonValue.apnsProduction.jsonStringValue
        case .sandbox:
            return JsonValue.apnsSandbox.jsonStringValue
        case .auto:
            return apnsType == .sandbox ? JsonValue.apnsSandbox.jsonStringValue : JsonValue.apnsProduction.jsonStringValue
        }
    }
    
    private func setCurrentUser(inDict dict: inout [AnyHashable: Any]) {
        switch auth.emailOrUserId {
        case let .email(email):
            dict.setValue(for: JsonKey.email, value: email)
        case let .userId(userId):
            dict.setValue(for: JsonKey.userId, value: userId)
        case .none:
            ITBInfo("Current user is unavailable")
        }

    }
}

// MARK: - DEPRECATED

extension RequestCreator {
    // deprecated - will be removed in version 6.3.x or above
    func createTrackInAppOpenRequest(_ messageId: String) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }
        
        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: messageId)
        
        setCurrentUser(inDict: &body)
        
        let inAppMessageContext = InAppMessageContext.from(messageId: messageId, deviceMetadata: deviceMetadata)
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        return .success(.post(createPostRequest(path: Const.Path.trackInAppOpen, body: body)))
    }
    
    // deprecated - will be removed in version 6.3.x or above
    func createTrackInAppClickRequest(_ messageId: String, clickedUrl: String) -> Result<IterableRequest, IterableError> {
        if case .none = auth.emailOrUserId {
            ITBError("Both email and userId are nil")
            return .failure(IterableError.general(description: "Both email and userId are nil"))
        }

        var body = [AnyHashable: Any]()
        
        body.setValue(for: JsonKey.messageId, value: messageId)
        body.setValue(for: JsonKey.clickedUrl, value: clickedUrl)
        
        setCurrentUser(inDict: &body)
        
        let inAppMessageContext = InAppMessageContext.from(messageId: messageId, deviceMetadata: deviceMetadata)
        body.setValue(for: JsonKey.inAppMessageContext, value: inAppMessageContext.toMessageContextDictionary())
        body.setValue(for: JsonKey.deviceInfo, value: deviceMetadata.asDictionary())
        
        return .success(.post(createPostRequest(path: Const.Path.trackInAppClick, body: body)))
    }
}
