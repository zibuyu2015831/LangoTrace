import Foundation

public enum LangoTraceAppCommand {
    public static let newEntry = Notification.Name("LangoTraceAppCommand.newEntry")
    public static let search = Notification.Name("LangoTraceAppCommand.search")
    public static let toggleSidebar = Notification.Name("LangoTraceAppCommand.toggleSidebar")
    public static let toggleInspector = Notification.Name("LangoTraceAppCommand.toggleInspector")
    public static let showSettings = Notification.Name("LangoTraceAppCommand.showSettings")
}
