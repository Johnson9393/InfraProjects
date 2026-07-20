import API_URL from "../config/api";

export const uploadCsv = async (file) => {
    const formData = new FormData();

    formData.append("file", file);

    const response = await fetch(
        `${API_URL}/api/quiz/questions/upload-csv`,
        {
            method: "POST",
            body: formData,
        }
    );

    if (!response.ok) {
        throw new Error("Failed to upload CSV");
    }

    return await response.json();
};