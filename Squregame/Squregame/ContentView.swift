//
//  ContentView.swift
//  Squregame
//
//  Created by sewmini  010   on 2025-05-04.
//
import SwiftUI
import AVFoundation

struct Square: Identifiable {
    let id = UUID()
    var color: Color
    var isRevealed: Bool = false
    var isMatched: Bool = false
    var isDummy: Bool = false
}

struct ContentView: View {
    @State private var squares: [Square] = []
    @State private var revealedIndices: [Int] = []
    @State private var score = 0
    @State private var highScore = UserDefaults.standard.integer(forKey: "HighScore")
    @State private var timeLeft = 30
    @State private var gameOver = false
    @State private var currentRound = 1
    let totalRounds = 3

    let gridSize = 3
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var columns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: gridSize)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.blue.opacity(0.4), .purple.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Score")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(score)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Time Left")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(timeLeft)s")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding(.top)

                Text("🎯 Round \(min(currentRound, totalRounds))/\(totalRounds)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                // Game Grid
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(squares.indices, id: \.self) { index in
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    squares[index].isMatched || squares[index].isRevealed || squares[index].isDummy ?
                                    squares[index].color : Color.white.opacity(0.15)
                                )
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 5, x: 2, y: 4)
                                .scaleEffect(squares[index].isRevealed ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: squares[index].isRevealed)
                        }
                        .onTapGesture {
                            if !squares[index].isDummy {
                                squareTapped(at: index)
                            }
                        }
                    }
                }
                .padding()

                // Game Over / Restart
                if gameOver {
                    VStack(spacing: 10) {
                        Text("Game Over")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)

                        Text("Final Score: \(score)")
                            .foregroundColor(.white.opacity(0.9))

                        Text("High Score: \(highScore)")
                            .foregroundColor(.yellow)

                        Button(action: {
                            score = 0
                            currentRound = 1
                            startGame()
                        }) {
                            Text("Restart Game")
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(LinearGradient(gradient: Gradient(colors: [.purple, .blue]), startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                                .shadow(radius: 10)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding()
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

    // MARK: - Game Logic
//
    func startGame() {
        if currentRound > totalRounds {
            gameOver = true
            updateHighScore()
            return
        }

        timeLeft = 30
        gameOver = false
        revealedIndices = []

        let tileCount = gridSize * gridSize
        let pairCount = tileCount / 2
        var baseColors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .teal, .mint]

        baseColors.shuffle()
        var colorPairs: [Square] = []

        for i in 0..<pairCount {
            let color = baseColors[i]
            colorPairs.append(Square(color: color))
            colorPairs.append(Square(color: color))
        }

        // Add dummy if tiles are odd
        if tileCount % 2 != 0 {
            colorPairs.append(Square(color: Color.gray.opacity(0.3), isDummy: true))
        }

        colorPairs.shuffle()
        squares = colorPairs
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
                    checkForRoundCompletion()
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

    func checkForRoundCompletion() {
        if squares.allSatisfy({ $0.isMatched || $0.isDummy }) {
            currentRound += 1
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

#Preview {
    ContentView()
}

