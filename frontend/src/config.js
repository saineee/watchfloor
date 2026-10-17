export const API_URL = import.meta.env.VITE_API_URL
if (API_URL === undefined) {
    throw new Error("VITE_API_URL not set.");
}
