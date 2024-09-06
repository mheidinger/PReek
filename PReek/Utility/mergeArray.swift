import Foundation

func mergeArray<T>(_ array: [(T, Bool)]) -> [T] {
    return array.reduce([T]()) { dataArray, element in
        let (data, merge) = element

        var newDataArray = dataArray
        if !dataArray.isEmpty, merge {
            newDataArray[newDataArray.endIndex - 1] = data
        } else {
            newDataArray.append(data)
        }
        return newDataArray
    }
}
