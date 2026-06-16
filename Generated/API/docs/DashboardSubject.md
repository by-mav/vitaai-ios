# DashboardSubject

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**name** | **String** |  | [optional] 
**shortName** | **String** |  | [optional] 
**difficulty** | **String** |  | [optional] 
**vitaScore** | **Double** | 0-100 mastery score | [optional] 
**vitaTier** | **String** | tier label: bronze, silver, gold, diamond | [optional] 
**subjectId** | **String** |  | [optional] 
**professor** | **String** |  | [optional] 
**status** | **String** | cursando | aprovado | reprovado | etc | [optional] 
**grade1** | **Double** |  | [optional] 
**grade2** | **Double** |  | [optional] 
**grade3** | **Double** |  | [optional] 
**finalGrade** | **Double** | DEPRECATED in favor of &#x60;evaluations[]&#x60; (kind&#x3D;final). Kept for back-compat. Hardcoded grade1/grade2/grade3/finalGrade only fits ULBRA AP1/AP2/AP3/Média pattern. For 350+ portals with varying schemes (P1/P2, N1/N2/Recup, etc.), iOS/Android should render &#x60;evaluations[]&#x60; dynamically.  | [optional] 
**evaluations** | [DashboardSubjectEvaluationsInner] | Per-subject canonical evaluations from &#x60;academic_evaluations&#x60;. Render dynamically — title, kind and sequence vary per portal/faculty (AP1/AS/Recuperação on ULBRA, P1/P2/Exame elsewhere). Sorted by (kind precedence: partial &lt; final &lt; makeup, then sequence).  | [optional] 
**attendance** | **Double** | 0-100 percent | [optional] 
**absences** | **Int** |  | [optional] 
**workload** | **Int** |  | [optional] 
**semester** | **String** |  | [optional] 
**disciplineSlug** | **String** | Canonical catalog slug from vita.disciplines. | [optional] 
**canonicalName** | **String** | Canonical name from vita.disciplines (joined). | [optional] 
**area** | **String** | Catalog area (basica, clinica, cirurgica, etc.). | [optional] 
**icon** | **String** | Icon slug from vita.disciplines. | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


