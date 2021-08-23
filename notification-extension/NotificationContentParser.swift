//
//  Copyright © 2021 Iterable. All rights reserved.
//

import Foundation
import UserNotifications

struct NotificationContentParser {
    static func getIterableMetadata(from content: UNNotificationContent) -> [AnyHashable: Any]? {
        content.userInfo[JsonKey.Payload.metadata] as? [AnyHashable: Any]
    }

    static func getIterableMessageId(from content: UNNotificationContent) -> String? {
        guard let metadata = getIterableMetadata(from: content) else {
            return nil
        }

        return metadata[JsonKey.Payload.messageId] as? String
    }

    static func getNotificationActions(from content: UNNotificationContent) -> [UNNotificationAction] {
        getActionButtonsJsonArray(from: content)
            .compactMap { createNotificationActionButton(from: $0) }
    }

    private static func getActionButtonsJsonArray(from content: UNNotificationContent) -> [[AnyHashable: Any]] {
        var jsonArray: [[AnyHashable: Any]] = []
        if let metadata = getIterableMetadata(from: content),
           let actionButtonsFromMetadata = metadata[JsonKey.Payload.actionButtons] as? [[AnyHashable: Any]] {
            jsonArray = actionButtonsFromMetadata
        } else {
            #if DEBUG
            if let actionButtonsFromUserInfo = content.userInfo[JsonKey.Payload.actionButtons] as? [[AnyHashable: Any]] {
                jsonArray = actionButtonsFromUserInfo
            }
            #endif
        }
        return jsonArray
    }

    private static func createNotificationActionButton(from json: [AnyHashable: Any]) -> UNNotificationAction? {
        guard let button = createActionButton(from: json) else {
            return nil
        }
        
        if button.buttonType == .textInput {
            if #available(iOS 15.0, *) {
                return UNTextInputNotificationAction(identifier: button.identifier,
                                                     title: button.title,
                                                     options: getOptions(forActionButton: button),
                                                     icon: getNotificationIcon(forActionButton: button),
                                                     textInputButtonTitle: button.textInputTitle ?? "",
                                                     textInputPlaceholder: button.textInputPlaceholder ?? "")
            } else {
                return UNTextInputNotificationAction(identifier: button.identifier,
                                                     title: button.title,
                                                     options: getOptions(forActionButton: button),
                                                     textInputButtonTitle: button.textInputTitle ?? "",
                                                     textInputPlaceholder: button.textInputPlaceholder ?? "")
            }
        } else {
            if #available(iOS 15.0, *) {
                return UNTextInputNotificationAction(identifier: button.identifier,
                                                     title: button.title,
                                                     options: getOptions(forActionButton: button),
                                                     icon: getNotificationIcon(forActionButton: button))
            } else {
                return UNTextInputNotificationAction(identifier: button.identifier,
                                                     title: button.title,
                                                     options: getOptions(forActionButton: button))
            }
        }
    }

    private static func createActionButton(from json: [AnyHashable: Any]) -> ActionButton? {
        guard let identifier = json[JsonKey.ActionButton.identifier] as? String else { return nil }
        guard let title = json[JsonKey.ActionButton.title] as? String else { return nil }
        
        return ActionButton(identifier: identifier,
                            title: title,
                            buttonType: getButtonType(info: json),
                            openApp: getBoolValue(json[JsonKey.ActionButton.openApp]) ?? true,
                            requiresUnlock: getBoolValue(json[JsonKey.ActionButton.requiresUnlock]) ?? false,
                            textInputTitle: json[JsonKey.ActionButton.inputTitle] as? String,
                            textInputPlaceholder: json[JsonKey.ActionButton.inputPlaceholder] as? String,
                            systemImageName: json[JsonKey.ActionButton.systemImageName] as? String,
                            templateImageName: json[JsonKey.ActionButton.templateImageName] as? String)
    }
    
    private static func getButtonType(info: [AnyHashable: Any]) -> ButtonType {
        if let buttonTypeRaw = info[JsonKey.ActionButton.buttonType] as? String,
            let buttonType = ButtonType(rawValue: buttonTypeRaw) {
            return buttonType
        }
        
        return .default
    }

    private static func getBoolValue(_ value: Any?) -> Bool? {
        return (value as? NSNumber)?.boolValue
    }

    private static func getOptions(forActionButton button: ActionButton) -> UNNotificationActionOptions {
        var options: UNNotificationActionOptions = []
        
        if button.buttonType == ButtonType.destructive {
            options.insert(.destructive)
        }
        
        if button.openApp {
            options.insert(.foreground)
        }
        
        if button.requiresUnlock || button.openApp {
            options.insert(.authenticationRequired)
        }
        
        return options
    }
    
    @available(iOS 15.0, *)
    private static func getNotificationIcon(forActionButton button: ActionButton) -> UNNotificationActionIcon? {
        if let systemImageName = button.systemImageName {
            return UNNotificationActionIcon(systemImageName: systemImageName)
        } else if let templateImageName = button.templateImageName {
            return UNNotificationActionIcon(templateImageName: templateImageName)
        } else {
            return nil
        }
    }
    
    private enum ButtonType: String {
        case `default`
        case destructive
        case textInput
    }

    private struct ActionButton {
        let identifier: String
        let title: String
        let buttonType: ButtonType
        let openApp: Bool
        let requiresUnlock: Bool
        let textInputTitle: String?
        let textInputPlaceholder: String?
        let systemImageName: String?
        let templateImageName: String?
    }
}
