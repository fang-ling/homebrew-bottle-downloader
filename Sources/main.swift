import Foundation

var pkg_urls = Set<String>()
var pkgs = Set<String>()

func download_pkg(
  name : String,
  version : String
) {
  if name.isEmpty {
    return;
  }
  var version = version
  if !version.contains("arm64") && version.first != " " {
    version = " " + version
  }

  /* Download formula code */
  var formula_url = "https://raw.githubusercontent.com/Homebrew/homebrew-core/"
  if name.starts(with: "lib") {
    formula_url += "master/Formula/lib/\(name).rb"
  } else {
    formula_url += "master/Formula/\(name.first!)/\(name).rb"
  }
  guard let formula = try? String(contentsOf: URL(string: formula_url)!) else {
    fatalError("Failed to download \(formula_url)")
  }
  /* Find matched hash */
  var hashes = formula.components(separatedBy: .newlines)
                 .filter{ $0.contains("sha256") }
  if hashes.filter({ $0.contains(version) }).isEmpty {
    hashes = hashes.filter { $0.contains("all") } /* Like ca-cetificates */
  }
  let hash_line = hashes.first!.trimmingCharacters(in: .whitespaces)
  let end_index = hash_line.index(before: hash_line.endIndex)
  let start_index = hash_line.index(end_index, offsetBy: -64)
  let hash = String(hash_line[start_index ..< end_index])

  /* Download pkg */
  /*
   * curl -L -H "Authorization: Bearer QQ==" -o name.tar.gz \
   * https://ghcr.io/v2/homebrew/core/name/blobs/sha256:hash
   */
  pkgs.insert(name)
  pkg_urls.insert/*print*/(
    """
    curl -L -H "Authorization: Bearer QQ==" -o \(name).tar.gz \
    https://ghcr.io/v2/homebrew/core/name/blobs/sha256:\(hash)
    """
  )
//  let url = URL(
//    string: "https://ghcr.io/v2/homebrew/core/\(name)/blobs/sha256:\(hash)"
//  )!
//  var request = URLRequest(url: url)
////  request.httpMethod = "POST"
//  request.addValue("Authorization", forHTTPHeaderField: "Bearer QQ==")
//  var task = URLSession.shared.downloadTask(
//    with: request
//  ) { _url, _response, _error in
//    guard let _url else {
//      return
//    }
//    do {
//      try FileManager.default.moveItem(
//        atPath: _url.path(),
//        toPath: "./\(name).tar.gz"
//      )
//    } catch {
//      print(error)
//    }
//  }
//  task.resume()
  /* Find dependencies */
  var formula_remove_linux : [String] = []
  var on_linux = false
  for line in formula.components(
    separatedBy: .newlines
  ).map({ $0.components(separatedBy: "#")[0] }) {
    if line.contains("on_linux") {
      on_linux = true
    }
    if !on_linux {
      formula_remove_linux.append(line)
    }
    /* depENDs contains end.... */
    if on_linux && line.trimmingCharacters(in: .whitespaces) == "end" {
      on_linux = false
    }
  }
  let dependencies = formula_remove_linux
    .filter { $0.contains("depends_on") }
    .filter { !$0.contains(":build") }
    .filter { !$0.contains(":test") }
    .map { $0.trimmingCharacters(in: .whitespaces) }
    /* depends_on " */
    .map { String($0[$0.index($0.startIndex, offsetBy: 12) ..< $0.endIndex]) }
    .map { String($0[$0.startIndex ..< $0.index(before: $0.endIndex)]) } /* " */
    .map { $0.components(separatedBy: "\"")[0] } /* gcc" if ... */
  /* Recursive on deps */
  for dependency in dependencies {
    if !pkgs.contains(dependency) { /* Skip already downloaded pkg */
      download_pkg(name: dependency, version: version)
    }
  }
}

download_pkg(name: CommandLine.arguments[1], version: CommandLine.arguments[2])
for pkg in pkg_urls {
  print(pkg)
}
