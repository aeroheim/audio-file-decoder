
function readFile(file: Blob): Promise<ArrayBuffer> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = (e) => {
      reader.abort();
      reject(e);
    };
    reader.onload = () => {
      resolve(reader.result as ArrayBuffer);
    };
    reader.readAsArrayBuffer(file);
  });
}

export {
  readFile,
};
