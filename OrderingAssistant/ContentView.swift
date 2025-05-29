import SwiftUI
import Speech
import AVFoundation

// MARK: - Product Models
struct Product: Identifiable {
    let id = UUID()
    let name: String
    let modifiers: [String]
}

struct MatchedProduct: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let modifiers: [String]?
}

// MARK: - SpeechRecognizer
class SpeechRecognizer: ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-IN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcribedText: String = ""

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    func startRecording() throws {
        transcribedText = ""

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        let inputNode = audioEngine.inputNode
        request.shouldReportPartialResults = true

        recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopRecording()
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

// MARK: - String Matching Extension
extension String {
    func containsPartialWords(from input: String) -> Bool {
        let selfWords = self.lowercased().split(separator: " ")
        for word in selfWords where word.count >= 3 {
            if input.contains(word) {
                return true
            }
        }
        return false
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var matchedProducts: [MatchedProduct] = []
    @State private var cart: [MatchedProduct] = []
    @State private var isVoiceModalPresented = false

    let products = [
        Product(name: "Wisconsin Mac & Cheese", modifiers: ["extra cheese", "no breadcrumbs", "add parmesan chicken", "spicy", "light cheese", "add bacon", "no sauce"]),
        Product(name: "Penne Rosa", modifiers: ["extra sauce", "add shrimp", "no tomato", "spicy", "light cream", "add grilled chicken", "no mushrooms"]),
        Product(name: "Pad Thai", modifiers: ["add tofu", "no egg", "extra peanuts", "spicy", "no cilantro", "add shrimp", "light sauce"]),
        Product(name: "Japanese Pan Noodles", modifiers: ["extra sauce", "add steak", "no broccoli", "sweet", "add mushrooms", "no onions", "add tofu"]),
        Product(name: "Spaghetti & Meatballs", modifiers: ["extra meatballs", "no cheese", "add parmesan chicken", "light marinara", "spicy", "no garlic", "add mushrooms"]),
        Product(name: "Zucchini Pesto", modifiers: ["no cheese", "add grilled chicken", "extra pesto", "no tomato", "light sauce", "add mushrooms", "gluten free"]),
        Product(name: "Buffalo Chicken Mac", modifiers: ["extra buffalo sauce", "add bacon", "no blue cheese", "spicy", "extra chicken", "no breadcrumbs", "light cheese"])
    ]

    var body: some View {
        NavigationView {
            ZStack {
                List(products) { product in
                    VStack(alignment: .leading) {
                        Text(product.name).font(.headline)
                        Text("Modifiers: \(product.modifiers.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isVoiceModalPresented = true
                        }) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                        .accessibilityLabel("Start voice ordering")
                    }
                }
            }
            .navigationTitle("Products")
            .navigationBarItems(trailing:
                NavigationLink(destination: CartView(cart: $cart)) {
                    Text("Cart (\(cart.count))")
                }
            )
            .sheet(isPresented: $isVoiceModalPresented) {
                VoiceDetectionScreen(
                    isPresented: $isVoiceModalPresented,
                    speechRecognizer: speechRecognizer,
                    matchedProducts: $matchedProducts,
                    cart: $cart,
                    products: products
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Voice Detection Bottom Sheet
struct VoiceDetectionScreen: View {
    @Binding var isPresented: Bool
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @Binding var matchedProducts: [MatchedProduct]
    @Binding var cart: [MatchedProduct]

    @State private var contextString: String = ""

    let products: [Product]
    @State private var animateMic = false

    var body: some View {
        VStack {
            HStack {
                Button("Close") {
                    isPresented = false
                }
                .padding(.leading)
                
                Spacer()
                
                Button("Stop") {
                    speechRecognizer.stopRecording()
                    animateMic = false
                    filterProducts(from: speechRecognizer.transcribedText)
                }
                .padding(.trailing)
            }
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundColor(animateMic ? .blue : .gray)
                    .frame(width: 70, height: 70)
                    .scaleEffect(animateMic ? 1.3 : 1)
                    .animation(animateMic ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: animateMic)

                Image(systemName: "mic.fill")
                    .foregroundColor(animateMic ? .blue : .gray)
                    .font(.system(size: 30, weight: .bold))
            }
            .padding(.bottom)


            if matchedProducts.isEmpty {
                Text("Say a product name to begin")
                    .foregroundColor(.gray)
                    .padding()
                Text(speechRecognizer.transcribedText)
                    .font(.title3)
                    .padding(.bottom)
            } else {
                Text(contextString.isEmpty ? "" : "You said: \(contextString)")
                    .font(.title3)
                    .padding(.bottom)

                List(matchedProducts) { product in
                    VStack(alignment: .leading) {
                        Text(product.name).bold()
                        if let mods = product.modifiers {
                            Text("Modifiers: \(mods.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Button("Add to Cart") {
                            withAnimation {
                                if !cart.contains(product) {
                                    cart.append(product)
                                }
                            }
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            matchedProducts = []
            do {
                try speechRecognizer.startRecording()
                animateMic = true
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
        .onDisappear {
            speechRecognizer.stopRecording()
            animateMic = false
        }
    }

    private func filterProducts(from input: String) {
        let lowerInput = input.lowercased()
        self.contextString = lowerInput
        matchedProducts = products.compactMap { product in
            guard product.name.lowercased().containsPartialWords(from: lowerInput) else { return nil }
            let matchedMods = product.modifiers.filter { lowerInput.contains($0.lowercased()) }
            return MatchedProduct(name: product.name, modifiers: matchedMods.isEmpty ? nil : matchedMods)
        }
    }
}

// MARK: - Cart Screen
struct CartView: View {
    @Binding var cart: [MatchedProduct]

    var body: some View {
        List {
            ForEach(cart) { item in
                VStack(alignment: .leading) {
                    Text(item.name).bold()
                    if let mods = item.modifiers {
                        Text("Modifiers: \(mods.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Your Cart")
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
