/*
 * LÖVE 2D Normal Mapping Shader with Phong Lighting
 * This shader implements realistic lighting using normal maps to create the illusion of surface detail
 */

// UNIFORM INPUTS (sent from Lua code)
uniform Image u_normalMap;        // Normal map texture - contains surface normal vectors encoded as RGB values
uniform vec3 u_ambientColor = vec3(0.0, 0.0, 0.0);  // Base ambient light color (global illumination)
uniform vec3 u_lightColor = vec3(1.0, 1.0, 1.0);    // Color/intensity of the light source
uniform vec3 u_lightCoords;       // 3D position of the light source (x, y, z)

/*
 * LÖVE 2D's main shader function
 * Called for each pixel (fragment) being rendered
 * 
 * Parameters:
 * - textureColor: The color from the main texture at this pixel
 * - texture: The main texture being drawn (wall.png)
 * - textureCoords: UV coordinates (0-1 range) for texture sampling
 * - screenCoords: Pixel coordinates on screen
 */
vec4 effect(vec4 textureColor, Image texture, vec2 textureCoords, vec2 screenCoords) {
    // Convert screen coordinates to 3D fragment position (Z=0 for 2D)
    vec3 fragCoords = vec3(screenCoords, 0);

    // === AMBIENT LIGHTING ===
    // Ambient light provides base illumination even in "shadows"
    // This prevents areas from being completely black
    const float ambientStrength = 0.1;  // 10% ambient contribution
    vec3 ambient = ambientStrength * u_ambientColor;

    // === NORMAL MAPPING ===
    // Sample the normal map to get the surface normal at this pixel
    vec3 norm = Texel(u_normalMap, textureCoords).rgb;
    // Normal maps store normals as RGB values (0-1), but we need them as vectors (-1 to 1)
    // So we transform: RGB(0-1) -> Normal(-1 to 1) using: normal = (rgb * 2) - 1
    norm = normalize(norm * 2.0 - 1.0);
    
    // Many normal maps are authored with the Y (green) channel using a "Y-up" convention (OpenGL),
    // but screen coordinates in LÖVE have Y increasing downward, and some tools export "DirectX style"
    // normal maps (Y-down). If lighting appears vertically inverted (highlights/shadows swapped),
    // flip the green channel to match the coordinate space.
    norm.y = -norm.y;

    // === DIFFUSE LIGHTING (Lambert's Law) ===
    // Calculate how much light hits this surface based on the angle between
    // the surface normal and the direction to the light source
    vec3 lightDir = normalize(u_lightCoords - fragCoords);  // Direction from fragment to light
    float diff = max(dot(norm, lightDir), 0.0);            // Dot product gives cos(angle)
    vec3 diffuse = diff * u_lightColor;                    // Scale light color by angle factor

    // === SPECULAR LIGHTING (Phong Reflection Model) ===
    // Creates shiny highlights where the viewer would see reflected light
    const float specularStrength = 0.5;                   // How shiny the surface is (50%)
    const vec3 viewCoords = vec3(0.0, 0.0, 3000.0);      // Camera/viewer position (far above the 2D plane)

    vec3 viewDir = normalize(viewCoords - fragCoords);     // Direction from fragment to viewer
    vec3 reflectDir = reflect(-lightDir, norm);           // Perfect reflection direction
    
    // Calculate specular intensity: how aligned is the view direction with the reflection?
    float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);  // Power of 32 = shininess factor
    vec3 specular = specularStrength * spec * u_lightColor;

    // === FINAL COLOR CALCULATION ===
    // Combine all three lighting components and multiply by the base texture color
    // This gives us: (Ambient + Diffuse + Specular) * BaseColor
    vec3 res = (ambient + diffuse + specular) * Texel(texture, textureCoords).rgb;
    
    // Return final color, preserving the original alpha channel
    return vec4(res, textureColor.a);
}