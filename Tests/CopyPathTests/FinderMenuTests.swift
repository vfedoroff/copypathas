import AppKit
import CopyPathCore
import FinderSync
import Testing

@Suite("Finder menu")
struct FinderMenuTests {
    @Test("exposes every format in one CopyPath submenu")
    func singleSubmenu() throws {
        let menu = FinderSync().menu(for: .contextualMenuForItems)

        #expect(menu.items.count == 1)
        let rootItem = try #require(menu.items.first)
        #expect(rootItem.title == "Copy Path As")

        let submenu = try #require(rootItem.submenu)
        #expect(submenu.items.map(\.title) == [
            "Copy Path",
            "Quoted Path",
            "Shell-Escaped Path",
            "File URL",
            "Filename",
            "Filename Without Extension",
            "Parent Folder",
            "JSON Array",
            "Markdown Link",
        ])
    }

    @Test("routes commands through selectors that survive Finder serialization")
    func selectorRouting() throws {
        let menu = FinderSync().menu(for: .contextualMenuForItems)
        let submenu = try #require(menu.items.first?.submenu)

        #expect(submenu.items.allSatisfy { $0.representedObject == nil })
        #expect(Set(submenu.items.compactMap(\.action)).count == PathFormat.allCases.count)
    }
}
