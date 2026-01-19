# C++ Patterns and Best Practices

This skill provides C++ patterns and conventions used in our codebase.

## Modern C++ Standards

Target: **C++17** minimum, **C++20** where available

## Memory Management

### Smart Pointers
```cpp
// Ownership transfer
std::unique_ptr<Aircraft> CreateAircraft();

// Shared ownership
std::shared_ptr<Texture> LoadTexture(const std::string& path);

// Non-owning reference
Aircraft* GetNearestAircraft();  // caller does NOT delete
```

### RAII Pattern
```cpp
class ScopedLock {
public:
    explicit ScopedLock(Mutex& m) : mutex_(m) { mutex_.Lock(); }
    ~ScopedLock() { mutex_.Unlock(); }
private:
    Mutex& mutex_;
};
```

## Error Handling

### Expected/Result Pattern
```cpp
#include <expected>  // C++23 or custom implementation

std::expected<Aircraft, Error> LoadAircraft(const std::string& path);

// Usage
auto result = LoadAircraft("cessna.acf");
if (result) {
    Aircraft& aircraft = *result;
} else {
    LogError(result.error());
}
```

### Exception Safety
- Basic guarantee: No resource leaks
- Strong guarantee: Operation succeeds or state unchanged
- Noexcept: Mark functions that cannot throw

## Threading

### Thread-Safe Singletons
```cpp
class Renderer {
public:
    static Renderer& Instance() {
        static Renderer instance;  // Thread-safe in C++11+
        return instance;
    }
private:
    Renderer() = default;
};
```

### Lock-Free Where Possible
```cpp
std::atomic<bool> isRunning_{true};
std::atomic<int> frameCount_{0};
```

## Performance

### Prefer Stack Allocation
```cpp
// Good
std::array<float, 16> matrix;

// Avoid if size is known at compile time
std::vector<float> matrix(16);
```

### Move Semantics
```cpp
std::vector<Vertex> GenerateMesh() {
    std::vector<Vertex> vertices;
    // ... populate
    return vertices;  // RVO/NRVO, no copy
}
```

### Cache-Friendly Data
```cpp
// Structure of Arrays (SoA) for hot paths
struct Particles {
    std::vector<float> x, y, z;
    std::vector<float> vx, vy, vz;
};

// Array of Structures (AoS) for clarity
struct Particle {
    Vec3 position;
    Vec3 velocity;
};
```

## Code Style

### Naming Conventions
- Classes: `PascalCase`
- Functions: `PascalCase` or `camelCase`
- Variables: `camelCase`
- Member variables: `camelCase_` (trailing underscore)
- Constants: `kPascalCase` or `ALL_CAPS`
- Namespaces: `lowercase`

### Header Organization
```cpp
#pragma once

// System headers
#include <vector>
#include <string>

// Third-party headers
#include <glm/glm.hpp>

// Project headers
#include "core/types.h"
#include "rendering/mesh.h"
```

### Forward Declarations
```cpp
// In headers, prefer forward declarations
class Texture;
class Material;

class Renderer {
    void Render(const Material* material);
};
```
