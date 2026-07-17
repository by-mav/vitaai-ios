# OnboardingV2Request

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**goal** | **String** | P1 — objetivo macro | 
**inFaculdade** | **String** | P2 — status faculdade. not_started representa vestibular; obrigatório exceto se goal&#x3D;REVALIDA | [optional] 
**semester** | **Int** | 1-8&#x3D;FACULDADE, 9-12&#x3D;INTERNATO. Pode ser omitido quando a pessoa graduanda pula os detalhes da universidade. | [optional] 
**university** | **String** | Display name da universidade | [optional] 
**universityId** | **String** | FK universities.id (preferido) | [optional] 
**universityLms** | **String** | Portal LMS: canvas today; moodle reserved for future OAuth/API partner integrations. | [optional] 
**selectedSubjects** | [OnboardingV2RequestSelectedSubjectsInner] |  | [optional] 
**studyGoal** | **String** | Objetivo de estudo (Aprovar 1ª, Top 10%, etc) | [optional] 
**academicPhase** | **String** | Fase acadêmica escolhida na abertura conversacional do onboarding | [optional] 
**preferredName** | **String** | Nome pelo qual o usuário pediu para o Vita chamá-lo | [optional] 
**targetSpecialty** | **String** | Slug de medical_specialties (apenas goal&#x3D;RESIDENCIA) | [optional] 
**targetInstitutions** | **[String]** | Bancas-alvo (apenas goal&#x3D;RESIDENCIA) | [optional] 
**currentStage** | **String** | Etapa Revalida (apenas goal&#x3D;REVALIDA) | [optional] 
**focusAreas** | **[String]** | Áreas de foco (apenas goal&#x3D;REVALIDA) | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


