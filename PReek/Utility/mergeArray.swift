import Foundation

func mergeArray<T, I>(_ array: [T], indicator: KeyPath<T, I?>) -> [T] {
    var result: [T] = []
    result.reserveCapacity(array.count)

    for element in array {
        let merge = element[keyPath: indicator] != nil

        if !result.isEmpty, merge {
            result[result.endIndex - 1] = element
        } else {
            result.append(element)
        }
    }

    return result
}
