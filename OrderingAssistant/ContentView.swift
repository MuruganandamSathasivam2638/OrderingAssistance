import SwiftUI
import Speech
import AVFoundation

// MARK: - Models

struct Product: Identifiable, Decodable {
    let id = UUID()
    let name: String
    let modifiers: [String]
    let quantity: Int?
}

struct ProductIntent: Decodable {
    let product: String
    let modifiers: [String]
    let quantity: Int?
}

struct OrderIntent: Decodable {
    let products: [ProductIntent]
}

class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (() -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🗣️ Finished speaking: \(utterance.speechString)")
        onFinish?()
    }
}

struct GradientBackgroundView: View {
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 7/255, green: 9/255, blue: 81/255),   // Dark Blue Top-Left
                Color(red: 11/255, green: 30/255, blue: 129/255), // Mid Blue
                Color(red: 25/255, green: 50/255, blue: 144/255), // Bright Blue
                Color(red: 40/255, green: 45/255, blue: 120/255)  // Deep Purple Bottom-Right
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct GradientBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        GradientBackgroundView()
    }
}

// MARK: - Repository

struct ProductRepository {
    static let products = [
        Product(name: "Wisconsin Mac & Cheese", modifiers: ["extra cheese", "no breadcrumbs", "add parmesan chicken"], quantity: 10),
        Product(name: "Penne Rosa", modifiers: ["extra sauce", "add shrimp", "no tomato"], quantity: 10),
        Product(name: "Pad Thai", modifiers: ["add tofu", "no egg", "extra peanuts"], quantity: 10),
        Product(name: "Japanese Pan Noodles", modifiers: ["extra sauce", "add steak", "no broccoli"], quantity: 10),
        Product(name: "Spaghetti & Meatballs", modifiers: ["extra meatballs", "no cheese", "add parmesan chicken"], quantity: 10),
        Product(name: "Zucchini Pesto", modifiers: ["no cheese", "add grilled chicken", "extra pesto"], quantity: 10),
        Product(name: "Buffalo Chicken Mac", modifiers: ["extra buffalo sauce", "add bacon", "no blue cheese"], quantity: 10)
    ]
    
    var detectedProducts: [Product]

}

// MARK: - ContentView

struct ContentView: View {
    @State private var isVoiceInputPresented = false
    let allProducts = ProductRepository.products
    @State var cartProducts: [Product]

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(allProducts) { product in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(product.name)
                                        .font(.headline)

                                    Text("Modifiers: \(product.modifiers.joined(separator: ", "))")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                            .shadow(radius: 2)
                        }
                    }
                    .padding()
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isVoiceInputPresented = true
                        }) {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.darkBlue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .navigationBarItems(trailing: NavigationLink(destination: CartView(cartProducts: $cartProducts)) {
                    Text("Cart (\(cartProducts.count))")
                }
            )
            .navigationTitle("Menu")
            .sheet(isPresented: $isVoiceInputPresented) {
                VoiceInputView(isPresented: $isVoiceInputPresented, cartProducts: $cartProducts)
            }
        }
    }
}

// MARK: - Cart Screen
struct CartView: View {
    @Binding var cartProducts: [Product]

    var body: some View {
        List {
            ForEach(cartProducts) { product in
                VStack(alignment: .leading) {
                    Text(product.name).bold()
                    Text("Modifiers: \(product.modifiers.joined(separator: ", "))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Your Cart")
    }
}

// MARK: - VoiceInputView

struct VoiceInputView: View {
    @Binding var isPresented: Bool
    @State private var userInput = ""
    @State private var detectedProducts: [Product] = []
    @State private var isListening = false
    @State private var isProcessing = false
    @State private var micPulse = false
    @State private var brainPulse = false
    @State private var isAnnouncing = false

    @Binding var cartProducts: [Product]

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioSession = AVAudioSession.sharedInstance()
    private let PRODUCT_ADDED_TO_CART = "Product added to cart:"
    private let PRODUCT_WITH_MODIFIERS = "with: "
    private let ADD_MORE_PRODUCTS = "Do you want to add more products? Tap the microphone to continue."
    @State private var recognitionTask: SFSpeechRecognitionTask?
    let synthesizer = AVSpeechSynthesizer()
    let delegate = SpeechDelegate()

    let allProducts = ProductRepository.products

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: {
                            isPresented = false
                        }){
                            Image(systemName: "xmark")
                                .foregroundColor(Color.black)
                                .padding()
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                }
                
                
                if !detectedProducts.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🛒 Detected Products")
                            .font(.headline)

                        ForEach(detectedProducts) { product in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name).font(.title3.bold())
                                ForEach(product.modifiers, id: \.self) {
                                    Text("• \($0)").foregroundColor(.gray)
                                }
                                Text("Quantity: \(product.quantity ?? 1)").font(.subheadline)
                                Divider().padding(.top, 4)
                            }
                        }
                    }
                    .padding()
                }  else if detectedProducts.isEmpty {
                    Spacer()
                    Text("Say something delicious, \nand I’ll handle the rest!")
                        .multilineTextAlignment(.center).foregroundColor(.secondary)
                    Spacer()
                } else if !isListening && !isProcessing {
                    Text("No products detected.")
                        .foregroundColor(.secondary)
                }

                Spacer()
                
                if !userInput.isEmpty {
                    Text(userInput)
                        .font(.body)
                        .italic()
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                if isListening {
                    LottieView(animationName: "listening")
                                    .frame(width: 200, height: 200)
                    //statusView(label: "Listening...", icon: "mic.fill", color: .blue, pulse: micPulse)
                } else if isProcessing {
                    LottieView(animationName: "processing").frame(width: 150, height: 150)
                    //statusView(label: "Processing...", icon: "cpu.fill", color: .green, pulse: brainPulse)
                } else if isAnnouncing {
                    LottieView(animationName: "announcing").frame(width: 150, height: 150)
                } else {
                    Button(action: {
                        startListening()
                    }) {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.darkBlue)
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                }
                
            }
            .padding()
            .onAppear(perform: startListening)
            .onDisappear(perform: stopListening)
            .navigationTitle("Voice Order")
            .navigationBarHidden(true)
        }
    }
    
    private func announceProducts(){
        let pauser = "."
        if(!detectedProducts.isEmpty){
            var announcementText = PRODUCT_ADDED_TO_CART + pauser
            detectedProducts.forEach { product in
                print("product \(product.name)")
                let quantityString = String(product.quantity ?? 0)
                announcementText += quantityString + pauser + product.name
                if(!product.modifiers.isEmpty){
                    announcementText += PRODUCT_WITH_MODIFIERS
                    product.modifiers.forEach{ modifier in
                        announcementText += modifier + pauser
                    }
                    announcementText += pauser
                }
            }
            announcementText += pauser + ADD_MORE_PRODUCTS
            isAnnouncing = true
            announce(announcementText: announcementText)
        }
    }
    
    private func announce(announcementText: String){
        let utterance = AVSpeechUtterance(string: announcementText)
                        utterance.rate = 0.5
                        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
                        synthesizer.delegate = delegate
                        delegate.onFinish = {
                            isAnnouncing = false
                        }
                        synthesizer.speak(utterance)
    }

    // MARK: - Views

    func statusView(label: String, icon: String, color: Color, pulse: Bool) -> some View {
        VStack(spacing: 12) {
            Text(label)
                .font(.headline)
                .foregroundColor(color)

            ZStack {
                Circle()
                    .stroke(lineWidth: 5)
                    .foregroundColor(color)
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulse ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 1), value: pulse)

                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 30, weight: .bold))
            }
        }
    }

    // MARK: - Speech Recognition

    func startListening() {
        isListening = true
        startPulse(for: .mic)

        SFSpeechRecognizer.requestAuthorization { status in
            guard status == .authorized else {
                print("Speech recognition not authorized")
                return
            }

            do {
                try audioSession.setCategory(.record, mode: .measurement)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true

                let inputNode = audioEngine.inputNode
                let recordingFormat = inputNode.outputFormat(forBus: 0)

                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    request.append(buffer)
                }

                audioEngine.prepare()
                try audioEngine.start()

                recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
                    if let result = result {
                        userInput = result.bestTranscription.formattedString
                    }
                    if error != nil || result?.isFinal == true {
                        stopListening()
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    stopListening()
                }

            } catch {
                print("Speech setup failed: \(error)")
                stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isListening = false
        isProcessing = true
        startPulse(for: .brain)

        Task {
            await processInput(userInput)
        }
    }

    enum PulseType { case mic, brain }

    func startPulse(for type: PulseType) {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            switch type {
            case .mic:
                if isListening { micPulse.toggle() } else { timer.invalidate() }
            case .brain:
                if isProcessing { brainPulse.toggle() } else { timer.invalidate() }
            }
        }
    }

    // MARK: - OpenAI Integration

    func processInput(_ input: String) async {
        let prompt = """
        You are a voice ordering assistant. Extract products, modifiers, and quantities from the text.

        Menu:
        \(allProducts.map { "- \($0.name): \($0.modifiers.joined(separator: ", "))" }.joined(separator: "\n"))

        User said: "\(input)"

        Format:
        {
          "products": [
            {
              "product": "<product name>",
              "modifiers": ["<modifier1>", "<modifier2>"],
              "quantity": 0
            }
          ]
        }
        """

        do {
            let response = try await callOpenAI(with: prompt)
            let decoded = try JSONDecoder().decode(OrderIntent.self, from: Data(response.utf8))

            detectedProducts = decoded.products.compactMap { intent in
                if let match = allProducts.first(where: { $0.name.lowercased() == intent.product.lowercased() }) {
                    return Product(name: match.name, modifiers: intent.modifiers, quantity: intent.quantity ?? 1)
                } else {
                    return Product(name: intent.product, modifiers: intent.modifiers, quantity: intent.quantity ?? 1)
                }
            }
            cartProducts.append(contentsOf: detectedProducts)
            if(!detectedProducts.isEmpty){
                announceProducts()
            }else{
                announce(announcementText: "No Products detected, Please try again!")
            }
        } catch {
            print("OpenAI error: \(error)")
        }

        isProcessing = false
    }

    func callOpenAI(with prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as! String

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant."],
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }
}
