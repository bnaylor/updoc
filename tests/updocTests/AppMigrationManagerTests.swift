import Testing
import Foundation
@testable import updoc

struct AppMigrationManagerTests {
    @Test func bareUncheckedBecomesGFM() {
        let input    = "[ ] buy milk"
        let expected = "- [ ] buy milk"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func bareCheckedBecomesGFM() {
        let input    = "[x] done task"
        let expected = "- [x] done task"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func uppercaseXNormalised() {
        let input    = "[X] Done"
        let expected = "- [x] Done"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func indentedLinePreservesIndent() {
        let input    = "  [ ] indented task"
        let expected = "  - [ ] indented task"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func alreadyGFMLineIsUntouched() {
        let input    = "- [ ] already correct"
        let expected = "- [ ] already correct"
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func bulletVariantsUntouched() {
        let input    = "* [ ] asterisk bullet\n+ [x] plus bullet"
        #expect(AppMigrationManager.migrateContent(input) == input)
    }

    @Test func multiLineDocumentMigratesOnlyBareLine() {
        let input = """
        # Heading
        [ ] task one
        - [ ] already done
        [x] completed
        Normal paragraph text
        """
        let expected = """
        # Heading
        - [ ] task one
        - [ ] already done
        - [x] completed
        Normal paragraph text
        """
        #expect(AppMigrationManager.migrateContent(input) == expected)
    }

    @Test func emptyStringReturnedUnchanged() {
        #expect(AppMigrationManager.migrateContent("") == "")
    }
}
