import React, { useEffect, useState } from "react";
import { Image, View } from "react-native";

const HOST = "http://192.168.18.14:5000";
const FPS = 6;

export default function CameraView() {
  const [uri, setUri] = useState(`${HOST}/frame.jpg`);

  useEffect(() => {
    const id = setInterval(() => {
      setUri(`${HOST}/frame.jpg?ts=${Date.now()}`); // cache-bust
    }, Math.round(1000 / FPS));
    return () => clearInterval(id);
  }, []);

  return (
    <View style={{ flex: 1, backgroundColor: "#000" }}>
      <Image source={{ uri }} style={{ width: "100%", height: "100%" }} resizeMode="contain" />
    </View>
  );
}
