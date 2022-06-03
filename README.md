# RefreshScrollView
SwiftUI async custom refreshable ScrollView

## Usage

```Swift
struct ContentView: View {

    var body: some View {
        RefreshScrollView(type: .progress) {
            // Content
            Text("Hello World!")
        } onRefresh: {
            await fetchService()
        }
    }

    func fetchService() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }
}
```
