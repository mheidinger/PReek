import Foundation

func mergeArray<T, I>(_ array: [T], indicator: KeyPath<T, I?>) -> [T] {
    return array.reduce([T]()) { dataArray, element in
        let merge = element[keyPath: indicator] != nil

        var newDataArray = dataArray
        if !dataArray.isEmpty, merge {
            newDataArray[newDataArray.endIndex - 1] = element
        } else {
            newDataArray.append(element)
        }
        return newDataArray
    }
}
