# SmartHire - Przykłady diagramów Mermaid

Ten plik zawiera przykłady kodu Mermaid do generowania różnych diagramów dla projektu SmartHire.

## 1. Diagram przepływu pracy (Flowchart)

```mermaid
flowchart TD
    A[Rekruter] -->|Dodaje CV| B(Analiza CV)
    B --> C{Wyniki analizy}
    C -->|Dobre dopasowanie| D[Ocena rekrutera]
    C -->|Słabe dopasowanie| E[Odrzucenie]
    D -->|Pozytywna| F[Rozmowa kwalifikacyjna]
    D -->|Negatywna| E
    F -->|Pozytywna| G[Oferta pracy]
    F -->|Negatywna| E
    G -->|Zaakceptowana| H[Zatrudnienie]
    G -->|Odrzucona| E
```

## 2. Diagram sekwencji (Sequence Diagram)

```mermaid
sequenceDiagram
    actor Rekruter
    participant UI as Interfejs użytkownika
    participant Controller as CVAnalysisController
    participant Service as CVAnalysisService
    participant AI as OpenAI API
    
    Rekruter->>UI: Dodaje CV
    UI->>Controller: analyzeCandidateResume()
    Controller->>Service: analyzeCandidateResume()
    Service->>Service: extractTextFromCV()
    Service->>AI: callOpenAI()
    AI-->>Service: Wyniki analizy
    Service-->>Controller: Wyniki analizy
    Controller-->>UI: Wyniki analizy
    UI-->>Rekruter: Wyświetla wyniki
```

## 3. Diagram klas (Class Diagram)

```mermaid
classDiagram
    class CVAnalysisController {
        +analyzeCandidateResume(contentDocumentId, positionId, bypassCache)
        +saveAnalysisResults(recordId, analysisResults)
    }
    
    class CVAnalysisService {
        -CACHE_PARTITION_NAME
        -CACHE_TTL
        +analyzeCandidateResume(contentDocumentId, positionId, bypassCache)
        -generateCacheKey(contentDocumentId)
        -getCachedResults(cacheKey, bypassCache)
        -saveToCache(cacheKey, results)
        -getContentVersion(contentDocumentId)
    }
    
    class CVAnalysisHelper {
        +analyzeResume(cv, positionId)
        -extractTextFromCV(cv)
        -parseAIResponse(aiResponse)
        -getPosition(positionId)
        -parseSkills(skillsString)
        -convertToText(cv)
        -parsePDF(pdfData)
        -parseWord(wordData)
    }
    
    class OpenAIService {
        -NAMED_CREDENTIAL
        -ENDPOINT_PATH
        -MAX_TOKENS
        +callOpenAI(prompt, systemPrompt)
        -validateOpenAISettingsAccess()
    }
    
    CVAnalysisController --> CVAnalysisService
    CVAnalysisService --> CVAnalysisHelper
    CVAnalysisHelper --> OpenAIService
```

## 4. Diagram encji (Entity Relationship Diagram)

```mermaid
erDiagram
    Job_Application__c ||--o{ Candidate__c : "ma"
    Job_Application__c ||--o{ Position__c : "dotyczy"
    
    Job_Application__c {
        string Name
        reference Candidate__c
        reference Position__c
        picklist Status__c
        date Application_Date__c
        reference Assigned_Reviewer__c
        textarea Notes__c
        textarea Analysis_Results__c
        number Analysis_Score__c
        string Skills_Identified__c
        datetime Analysis_Date__c
    }
    
    Candidate__c {
        string First_Name__c
        string Last_Name__c
        email Email__c
        phone Phone__c
        string Skills__c
        number Experience_Years__c
        string Education__c
        reference Contact__c
        textarea Analysis_Results__c
        datetime Last_Analysis_Date__c
    }
    
    Position__c {
        string Name
        textarea Description__c
        string Department__c
        string Required_Skills__c
        picklist Status__c
        reference Hiring_Manager__c
    }
```

## 5. Diagram stanów (State Diagram)

```mermaid
stateDiagram-v2
    [*] --> Nowa
    Nowa --> W_trakcie_analizy: Dodanie CV
    W_trakcie_analizy --> Przeanalizowana: Analiza zakończona
    Przeanalizowana --> W_trakcie_oceny: Przekazanie do oceny
    W_trakcie_oceny --> Zaakceptowana: Pozytywna ocena
    W_trakcie_oceny --> Odrzucona: Negatywna ocena
    Zaakceptowana --> [*]
    Odrzucona --> [*]
    Nowa --> Odrzucona: Bezpośrednie odrzucenie
```

## 6. Diagram Gantta (Gantt Chart)

```mermaid
gantt
    title Harmonogram wdrożenia SmartHire
    dateFormat  YYYY-MM-DD
    
    section Faza 1
    Analiza wymagań           :a1, 2025-01-01, 30d
    Projektowanie architektury :a2, after a1, 20d
    
    section Faza 2
    Implementacja modelu danych :b1, after a2, 15d
    Implementacja kontrolerów   :b2, after b1, 10d
    Implementacja serwisów      :b3, after b1, 15d
    
    section Faza 3
    Integracja z OpenAI         :c1, after b3, 10d
    Implementacja UI            :c2, after b2, 20d
    
    section Faza 4
    Testy                       :d1, after c1, 15d
    Poprawki                    :d2, after d1, 10d
    Wdrożenie                   :d3, after d2, 5d
```

## 7. Diagram pie (Pie Chart)

```mermaid
pie
    title Rozkład czasu implementacji
    "Model danych" : 15
    "Kontrolery" : 20
    "Serwisy" : 25
    "Integracja z OpenAI" : 15
    "UI" : 25
```

## 8. Diagram użytkownika (User Journey)

```mermaid
journey
    title Proces rekrutacji w SmartHire
    section Dodanie CV
        Dodanie CV: 5: Rekruter
        Analiza CV: 3: System
        Przegląd wyników: 4: Rekruter
    section Ocena kandydata
        Ocena dopasowania: 4: Rekruter
        Decyzja o rozmowie: 3: Rekruter, Menedżer
    section Rozmowa kwalifikacyjna
        Zaproszenie na rozmowę: 5: System
        Przeprowadzenie rozmowy: 3: Rekruter, Menedżer
        Ocena po rozmowie: 4: Rekruter, Menedżer
    section Zatrudnienie
        Oferta pracy: 5: Menedżer
        Konwersja kandydata: 4: System
```

## Jak używać tych diagramów

1. Skopiuj kod diagramu, który chcesz użyć
2. Wklej go do pliku Markdown w swoim repozytorium
3. Dostosuj diagram do swoich potrzeb
4. Renderuj plik Markdown w środowisku, które obsługuje Mermaid (np. GitHub, GitLab, VS Code z odpowiednim rozszerzeniem)

## Dodatkowe zasoby

- [Oficjalna dokumentacja Mermaid](https://mermaid-js.github.io/mermaid/#/)
- [Edytor online Mermaid Live Editor](https://mermaid-js.github.io/mermaid-live-editor/)
- [Rozszerzenie VS Code dla Mermaid](https://marketplace.visualstudio.com/items?itemName=bierner.markdown-mermaid)