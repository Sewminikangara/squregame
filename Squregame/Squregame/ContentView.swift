//
//  ContentView.swift
//  Squregame
//
//  Created by sewmini  010   on 2025-05-04.
//
//
//  ContentView.swift
//  Squregame
//
//  Created by sewmini 010 on 2025-05-04.
//

import SwiftUI
import AVFoundation

// MARK: - Models and Enums

enum TileShape {
    case rounded, circle, diamond
}

struct Square: Identifiable {
    let id = UUID()
    var color: Color
    var isRevealed: Bool = false
    var isMatched: Bool = false
    var isDummy: Bool = false
}

// MARK: - AnyShape Wrapper

struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        self.pathBuilder = shape.path(in:)
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Custom Diamond Shape

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: midY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Subview for Square Tile

struct SquareTileView: View {
    let square: Square
    let shape: TileShape
    let onTap: () -> Void

    var body: some View {
        let viewShape = shapeAsShape()

        ZStack {
            viewShape
                .fill(square.isMatched || square.isRevealed || square.isDummy ?
                      square.color : Color.white.opacity(0.15))
                .frame(height: 90)
                .overlay(
                    viewShape
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 5, x: 2, y: 4)
                .scaleEffect(square.isRevealed ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: square.isRevealed)
        }
        .onTapGesture {
            onTap()
        }
    }

    func shapeAsShape() -> AnyShape {
        switch shape {
        case .rounded:
            return AnyShape(RoundedRectangle(cornerRadius: 18))
        case .circle:
            return AnyShape(Circle())
        case .diamond:
            return AnyShape(DiamondShape())
        }
    }
}

// MARK: - Start View

struct StartView: View {
    @Binding var showGame: Bool

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("🎮 Square Match Game")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("🟪 Match the colored shapes\n🕒 Finish before time runs out\n⭐ Score more to level up")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Button(action: {
                    showGame = true
                }) {
                    Text("Start Game")
                        .padding()
                        .frame(width: 200)
                        .background(Color.white)
                        .foregroundColor(.purple)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                }
            }
            .padding()
        }
    }
}

// MARK: - Main Game View

struct GameView: View {
    @State private var squares: [Square] = []
    @State private var revealedIndices: [Int] = []
    @State private var score = 0
    @State private var highScore = UserDefaults.standard.integer(forKey: "HighScore")
    @State private var timeLeft = 30
    @State private var gameOver = false
    @State private var level = 1
    @State private var gridSize = 3

    let maxLevel = 10
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: gridSize)
    }

    var shapeForLevel: TileShape {
        switch level % 3 {
        case 0: return .diamond
        case 1: return .rounded
        default: return .circle
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.4), .purple.opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Score")
                        Text("\(score)").font(.title).fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Time")
                        Text("\(timeLeft)s").font(.title).fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                Text("🎮 Level \(level)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(squares.indices, id: \.self) { index in
                        SquareTileView(square: squares[index], shape: shapeForLevel) {
                            if !squares[index].isDummy {
                                squareTapped(at: index)
                            }
                        }
                    }
                }
                .padding()

                if gameOver {
                    VStack(spacing: 10) {
                        Text("Game Over").font(.title2).bold().foregroundColor(.white)
                        Text("Final Score: \(score)").foregroundColor(.white.opacity(0.9))
                        Text("High Score: \(highScore)").foregroundColor(.yellow)

                        Button("Restart Game") {
                            score = 0
                            level = 1
                            startGame()
                        }
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear(perform: startGame)
        .onReceive(timer) { _ in
            if timeLeft > 0 && !gameOver {
                timeLeft -= 1
            } else if !gameOver {
                gameOver = true
                updateHighScore()
            }
        }
    }

    func startGame() {
        if level > maxLevel {
            gameOver = true
            updateHighScore()
            return
        }

        timeLeft = max(10, 30 - (level * 2))
        gridSize = min(6, 3 + (level / 2))

        gameOver = false
        revealedIndices = []

        let tileCount = gridSize * gridSize
        let pairCount = tileCount / 2
        var baseColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal, .mint, .cyan, .indigo]
        baseColors.shuffle()

        var colorPairs: [Square] = []

        for i in 0..<pairCount {
            let color = baseColors[i % baseColors.count]
            colorPairs.append(Square(color: color))
            colorPairs.append(Square(color: color))
        }

        if tileCount % 2 != 0 {
            colorPairs.append(Square(color: Color.gray.opacity(0.3), isDummy: true))
        }

        squares = colorPairs.shuffled()
    }

    func squareTapped(at index: Int) {
        guard !squares[index].isMatched,
              !squares[index].isRevealed,
              !squares[index].isDummy,
              revealedIndices.count < 2 else { return }

        squares[index].isRevealed = true
        revealedIndices.append(index)

        if revealedIndices.count == 2 {
            let first = revealedIndices[0]
            let second = revealedIndices[1]

            if squares[first].color == squares[second].color {
                score += 10
                playSound(name: "success")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    squares[first].isMatched = true
                    squares[second].isMatched = true
                    revealedIndices.removeAll()
                    checkForLevelCompletion()
                }
            } else {
                playSound(name: "fail")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    squares[first].isRevealed = false
                    squares[second].isRevealed = false
                    revealedIndices.removeAll()
                }
            }
        }
    }

    func checkForLevelCompletion() {
        if squares.allSatisfy({ $0.isMatched || $0.isDummy }) {
            level += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startGame()
            }
        }
    }

    func updateHighScore() {
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "HighScore")
        }
    }

    func playSound(name: String) {
        let soundID: SystemSoundID = (name == "success") ? 1057 : 1073
        AudioServicesPlaySystemSound(soundID)
    }
}

// MARK: - Main ContentView

struct ContentView: View {
    @State private var showGame = false

    var body: some View {
        if showGame {
            GameView()
        } else {
            StartView(showGame: $showGame)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
