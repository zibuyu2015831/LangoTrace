@testable import LangoTraceCore
import Testing

@Test("Product identity exposes the fixed app name and slogans")
func productIdentityExposesFixedNameAndSlogans() {
    #expect(ProductIdentity.chineseName == "语迹")
    #expect(ProductIdentity.englishName == "LangoTrace")
    #expect(ProductIdentity.displayName == "语迹 / LangoTrace")
    #expect(ProductIdentity.chineseSlogan == "用生活记录学习语言。")
    #expect(ProductIdentity.englishSlogan == "Learn languages from your life.")
}
