## 1.0.0

* Initial stable production release of `face_liveness_check`.
* Real-time on-device facial liveness detection powered by Google ML Kit.
* Supported challenge steps: `blink`, `smile`, `turnHeadLeft`, `turnHeadRight`, and `lookStraight`.
* Guaranteed frontal straight-head photo capture: regardless of challenge order, reference photo is only taken when user faces forward with eyes open.
* Full UI customizability: colors, oval dimensions, cards, buttons, and progress indicators.
* Complete localization support for all instructions, hints, and error states (including pre-built `LivenessConfig.arabic()` preset).
* Convenient `FaceLivenessCheck.start(context)` helper method.
* Automatic EXIF orientation baking on captured reference photos.
* Performance optimized: cached camera sensor orientation and single-plane memory buffers.
