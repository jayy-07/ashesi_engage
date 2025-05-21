import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'proposal_details_viewmodel.dart';

class AdminProposalDetailsViewModel extends ProposalDetailsViewModel {
  AdminProposalDetailsViewModel(
    super.proposal,
    super.context,
    super.proposalService,
  );

  @override
  Future<void> generateSummary() async {
    if (comments.isEmpty) {
      updateAISummaryState(
        isLoading: false,
        summary: '',
        hasGenerated: false,
      );
      notifyListeners();
      return;
    }

    updateAISummaryState(
      isLoading: true,
      summary: '',
      hasGenerated: false,
    );
    notifyListeners();

    try {
      final model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-1.5-flash-002'
      );

      final commentTexts = comments.map((c) => c.content).join('\n');
      
      final prompt = [
        Content.text(
          """
          You are analyzing feedback on a student proposal from Ashesi University's e-participation platform. This platform enables students to submit formal proposals to the Student Council for campus improvements, policy changes, or new initiatives. The Council uses this feedback to evaluate and refine proposals before implementation.

          Your task is to synthesize the community feedback in a way that helps the Student Council understand the collective response and evaluate implementation feasibility.

          Context (Proposal): ${proposal.plainContent}

          Feedback comments to analyze:
          $commentTexts

          Generate a structured summary in this exact markdown format:

          ##### **Key Community Feedback**
          * [1-3 main points of student feedback, one per bullet]

          ##### **Strengths Highlighted**
          * [1-2 positive aspects that resonate with the student body]

          ##### **Concerns Raised**
          * [1-2 main concerns or issues identified by students]

          ##### **Implementation Considerations**
          * [2-3 points about feasibility, resources, execution requirements, and potential challenges within the Ashesi context]

          Requirements:
          - Use exactly the markdown headings shown above (##### and ** for each heading)
          - Use markdown bullet points (*)
          - Keep each bullet point to 1-2 sentences maximum
          - Use clear, objective language
          - Focus on concrete feedback and actionable insights
          - If a section has no relevant points, write "None identified."
          - Maintain neutral tone throughout
          - Never mention comment counts or use phrases like "users say" or "participants mention"
          - Ensure there is a blank line after each heading and between bullet points
          - Frame feedback in the context of Ashesi University and student council implementation
          - Consider both student body impact and administrative feasibility
          - In Implementation Considerations, focus on practical aspects like:
            * Resource requirements (budget, staff, infrastructure)
            * Timeline considerations
            * Regulatory or policy implications
            * Potential challenges or risks
            * Dependencies on other departments or external factors
          """
        )
      ];

      cancelCurrentSummarySubscription();
      updateAISummaryState(
        isLoading: true,
        summary: '',
        hasGenerated: false,
      );

      String currentSummary = '';
      await for (final chunk in model.generateContentStream(prompt)) {
        if (chunk.text != null && chunk.text!.isNotEmpty) {
          HapticFeedback.lightImpact();
          currentSummary += chunk.text!;
          updateAISummaryState(
            isLoading: true,
            summary: currentSummary,
            hasGenerated: false,
          );
          notifyListeners();
        }
      }

      updateAISummaryState(
        isLoading: false,
        summary: currentSummary,
        hasGenerated: true,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error generating summary: $e');
      updateAISummaryState(
        isLoading: false,
        summary: 'Unable to generate summary at this time.',
        hasGenerated: false,
      );
      notifyListeners();
    }
  }
} 