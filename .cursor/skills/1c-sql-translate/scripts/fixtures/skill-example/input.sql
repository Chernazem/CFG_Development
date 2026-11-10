SELECT
    T._Period,
    T._Fld26004RRef,
    T._Fld26005RRef,
    T._Fld26006
FROM
    dbo._InfoRg26003 AS T
WHERE
    T._Period <= ?
    AND T._Fld26004RRef = ?