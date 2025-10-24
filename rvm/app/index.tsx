import { Audio } from "expo-av";
import { Image } from 'expo-image';
import { lockAsync, OrientationLock } from 'expo-screen-orientation';
import { useEffect, useRef, useState } from 'react';
import { Modal, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import type { WebViewErrorEvent, WebViewHttpErrorEvent } from "react-native-webview";
import { WebView } from "react-native-webview";


const PI_IP = "http://192.168.18.14:5000";

export default  function HomeScreen() {
  const [status, setStatus] = useState<{ last_code?: string; points?: number }>({});
  const soundRef = useRef<Audio.Sound | null>(null);
  const [webViewError, setWebViewError] = useState<string | null>(null);
  const [showModal, setShowModal] = useState<boolean>(false);
  const webViewRef = useRef<WebView | null>(null);

  async function playDing() {
    try {
      if (soundRef.current) {
        // Reset the sound to the beginning and play
        await soundRef.current.setPositionAsync(0);
        await soundRef.current.playAsync();
      }
    } catch (e) {
      console.log("Error playing sound", e);
    }
  }

  // poll status JSON and initialize sound
  useEffect(() => {
    // Load sound on mount
    const loadSound = async () => {
      try {
        const { sound } = await Audio.Sound.createAsync(
          require("@/assets/ding.mp3")
        );
        soundRef.current = sound;
      } catch (e) {
        console.log("Error loading sound", e);
      }
    };

    loadSound();

    const interval = setInterval(async () => {
      try {
        const res = await fetch(`${PI_IP}/status`);
        const json = await res.json();

        setStatus((prevStatus) => {
          if (json?.points > (prevStatus?.points || 0)) playDing();
          return { ...prevStatus, ...json };
        });
      } catch (e) {
        console.log("Error fetching status", e);
      }
    }, 500);

    lockAsync(OrientationLock.LANDSCAPE).catch((e) => {
      console.log("Error locking orientation", e);
    });

    fetch(`${PI_IP}/reseed`).then(() => {
      console.log("Reseeded");
    }).catch((e) => {
      console.log("Error reseeding", e);
    });

    return () => {
      clearInterval(interval);
      // Cleanup sound on unmount
      if (soundRef.current) {
        soundRef.current.unloadAsync().catch((e) => {
          console.log("Error unloading sound", e);
        });
      }
    };
  }, []);

  function handleWebViewNetworkError(event: WebViewErrorEvent | WebViewHttpErrorEvent) {
    const { nativeEvent } = event;
    const description = "description" in nativeEvent && nativeEvent.description
      ? nativeEvent.description
      : "statusCode" in nativeEvent
        ? `HTTP ${nativeEvent.statusCode}`
        : undefined;

    const message = description || "Unable to load stream.";
    setWebViewError(message);
    console.log("WebView network error", message);
  }

  function handleRetry() {
    setWebViewError(null);
  }

  async function handleReset() {
    try {
      await fetch(`${PI_IP}/reset`, { method: "POST" });
      setStatus({});
      setShowModal(false);
    } catch (e) {
      console.log("Error resetting", e);
    }
  }

  if (webViewError) return (
    <View style={styles.errorOverlay}>
      <Text style={styles.errorTitle}>Stream Unavailable</Text>
      <Text style={styles.errorMessage}>{webViewError}</Text>
      <TouchableOpacity style={styles.retryButton} onPress={handleRetry}>
        <Text style={styles.retryText}>Retry</Text>
      </TouchableOpacity>
    </View>
  );
  
  return (
    <View style={{ flex: 1, backgroundColor: "#000", position: "relative" }}>
      <WebView
        ref={webViewRef}
        style={{flex: 1}}
        source={{ uri: `${PI_IP}/stream` }}
        onError={handleWebViewNetworkError}
        onHttpError={handleWebViewNetworkError}
      />

      <View style={styles.pointsContainer}>
        <Text style={styles.pointsLabel}>Points</Text>
        <Text style={styles.pointsValue}>{status?.points ?? 0}</Text>
      </View>

      <TouchableOpacity 
        style={styles.doneButton} 
        onPress={() => setShowModal(true)}
      >
        <Text style={styles.doneButtonText}>Done</Text>
      </TouchableOpacity>

      <Modal
        visible={showModal}
        transparent={true}
        animationType="fade"
        onRequestClose={() => setShowModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContainer}>
            <Text style={styles.modalTitle}>Scan QR code with the GreenAfrica app</Text>
            
            <View style={styles.qrContainer}>
              <Image
                source={{ uri: `${PI_IP}/qr.png?code=${status?.last_code}` }}
                style={styles.qrImage}
                contentFit="contain"
              />
            </View>

            {status?.last_code && (
              <View style={styles.codeContainer}>
                <Text style={styles.codeText}>Code: {status.last_code}</Text>
              </View>
            )}

            <TouchableOpacity 
              style={styles.resetButton} 
              onPress={handleReset}
            >
              <Text style={styles.resetButtonText}>Reset & Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  titleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  stepContainer: {
    gap: 8,
    marginBottom: 8,
  },
  reactLogo: {
    height: 178,
    width: 290,
    bottom: 0,
    left: 0,
    position: 'absolute',
  },
  errorOverlay: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: "rgba(0, 0, 0, 0.95)",
    justifyContent: "center",
    alignItems: "center",
    paddingHorizontal: 24,
  },
  errorTitle: {
    fontSize: 24,
    fontWeight: "600",
    color: "#fff",
    marginBottom: 12,
    textAlign: "center",
  },
  errorMessage: {
    fontSize: 16,
    color: "#ccc",
    textAlign: "center",
    marginBottom: 24,
  },
  retryButton: {
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 24,
    backgroundColor: "#fff",
  },
  retryText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#000",
  },
  pointsContainer: {
    position: "absolute",
    top: 20,
    left: 20,
    backgroundColor: "rgba(0, 0, 0, 0.7)",
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
  },
  pointsLabel: {
    fontSize: 12,
    color: "#fff",
    opacity: 0.8,
  },
  pointsValue: {
    fontSize: 22,
    fontWeight: "700",
    color: "#fff",
  },
  doneButton: {
    position: "absolute",
    top: 20,
    right: 20,
    backgroundColor: "#fff",
    borderRadius: 25,
    paddingHorizontal: 20,
    paddingVertical: 10,
    shadowColor: "#000",
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  doneButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#000",
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: "rgba(0, 0, 0, 0.8)",
    justifyContent: "center",
    alignItems: "center",
  },
  modalContainer: {
    backgroundColor: "#fff",
    borderRadius: 20,
    padding: 30,
    alignItems: "center",
    maxWidth: "90%",
    width: 350,
    shadowColor: "#000",
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#000",
    textAlign: "center",
    marginBottom: 20,
  },
  qrContainer: {
    backgroundColor: "#f8f8f8",
    borderRadius: 15,
    padding: 15,
    marginBottom: 20,
  },
  qrImage: {
    width: 200,
    height: 200,
  },
  codeContainer: {
    backgroundColor: "#f0f0f0",
    borderRadius: 10,
    padding: 15,
    marginBottom: 20,
    minWidth: 200,
  },
  codeText: {
    fontSize: 16,
    color: "#000",
    textAlign: "center",
    fontWeight: "500",
  },
  resetButton: {
    backgroundColor: "#1b5e20",
    borderRadius: 25,
    paddingHorizontal: 30,
    paddingVertical: 12,
  },
  resetButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#fff",
  },
});
