export async function fetchNui(eventName, data) {
  const options = {
    method: "post",
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify(data),
  };
  fetch(`https://dusa_bridge/${eventName}`, options);
}