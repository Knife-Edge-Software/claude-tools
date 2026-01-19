# Flight Simulation Domain Knowledge

This skill provides domain-specific knowledge for flight simulation development.

## Units and Conventions

### Length/Distance
- **Internal:** Meters (m)
- **Display:** Feet (ft) for altitude, nautical miles (nm) for distance
- Conversion: 1 nm = 1852 m, 1 ft = 0.3048 m

### Speed
- **Internal:** Meters per second (m/s)
- **Display:** Knots (kt) for airspeed/groundspeed
- Conversion: 1 kt = 0.514444 m/s

### Angles
- **Internal:** Radians
- **Display:** Degrees
- Heading: 0-360 (magnetic north = 0)
- Pitch: Positive = nose up
- Roll/Bank: Positive = right wing down

### Time
- **Simulation:** Variable time step (delta time)
- **Real-time:** 1:1 ratio unless time acceleration active

## Coordinate Systems

### World Coordinates (ECEF)
- Earth-Centered, Earth-Fixed
- X: Through equator at prime meridian
- Y: Through equator at 90°E
- Z: Through north pole

### Local Coordinates (NED)
- North-East-Down relative to aircraft
- Used for aerodynamics calculations

### Body Coordinates
- X: Forward (through nose)
- Y: Right (through right wing)
- Z: Down (through belly)

## Performance Considerations

### Frame Rate Targets
- **Minimum:** 30 FPS
- **Target:** 60 FPS
- **VR:** 90 FPS

### Update Priorities
1. Flight model (physics) - Every frame
2. Collision detection - Every frame
3. AI aircraft - 10-30 Hz
4. Weather updates - 1 Hz
5. Terrain loading - As needed

### Memory Budgets
- Terrain textures: 512 MB - 2 GB
- Aircraft models: 128 MB each
- Sound buffers: 256 MB

## Common Patterns

### State Updates
```cpp
// Always use delta time for physics
velocity += acceleration * deltaTime;
position += velocity * deltaTime;
```

### Interpolation
- Use quaternions for rotation interpolation (avoid gimbal lock)
- Linear interpolation for position between network updates

### Level of Detail (LOD)
- Distance-based model switching
- Impostor rendering for distant aircraft
- Terrain tessellation based on view distance
