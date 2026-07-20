import React, { useState } from "react";
import { uploadCsv } from "../services/uploadService";

function UploadQuestions() {
    const [file, setFile] = useState(null);
    const [message, setMessage] = useState("");

    const handleUpload = async () => {
        if (!file) {
            setMessage("Please select a CSV file.");
            return;
        }

        try {
            const response = await uploadCsv(file);
            setMessage(response.message);
        } catch (error) {
            setMessage(error.message);
        }
    };

    return (
        <div className="max-w-xl mx-auto mt-10 bg-white shadow rounded p-6">
            <h2 className="text-2xl font-bold mb-6">
                Upload Transactions CSV
            </h2>

            <input
                type="file"
                accept=".csv"
                onChange={(e) => setFile(e.target.files[0])}
                className="mb-4"
            />

            <button
                onClick={handleUpload}
                className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
                Upload
            </button>

            {message && (
                <p className="mt-4 text-sm">
                    {message}
                </p>
            )}
        </div>
    );
}

export default UploadQuestions;