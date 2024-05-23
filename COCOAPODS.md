# CocoaPods release process

1. Update `s.version` in `FMDB.Podspec`.
2. Tag the release (`git tag x.y.z && git push --tags`).
3. Lint the podspec as a pre-check.
 - Run `pod spec lint` from within a clean working copy.
 - If you have any failures, address the errors mentioned.
 - Sometimes, errors are cryptic. A common problem is not having **all** of the supported simulators (macOS, iOS, watchOS, and tvOS) installed and updated.
 - You can narrow down the problem platform(s) with e.g. `pod spec lint --platforms=watchos` to see which pass and which fail.
 - You can also get a _lot_ more info with `pod spec lint --verbose`.
4. Push the podspec up to CocoaPods with `pod trunk push`. You will need access as well as an active session (`pod trunk me` / `pod trunk register`).
5. 🍻