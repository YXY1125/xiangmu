/**
 * Gate B source index. The dependency-free production entry is runtime/server.mjs.
 * Keeping this index makes the local server layout explicit without introducing
 * a second framework runtime or duplicating the HTTP implementation.
 */
export const runtimeEntry = '../runtime/server.mjs'
