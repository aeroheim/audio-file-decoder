
function readBuffer(fileOrBuffer: Blob | ArrayBuffer): Promise<ArrayBuffer> {
  return new Promise((resolve, reject) => {
    if (fileOrBuffer instanceof Blob) {
      const reader = new FileReader();
      reader.onerror = (e) => {
        reader.abort();
        reject(e);
      };
      reader.onload = () => {
        resolve(reader.result as ArrayBuffer);
      };
      reader.readAsArrayBuffer(fileOrBuffer);
    } else {
      resolve(fileOrBuffer);
    }
  });
}

export {
  readBuffer,
};
