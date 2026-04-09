import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_validator/form_validator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lms/app/core/core.dart';
import 'package:lms/app/features/courses/module/courses_module.dart';
import 'package:lms/gen/assets.gen.dart';

import '../viewmodel/signin_viewmodel.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(SignInViewModel.provider);
    return Scaffold(
      body: Stack(
        children: [
          Assets.images.loginBg.image(
            height: context.screenSize.height,
            fit: BoxFit.fitHeight,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(context.xLargeSpace),
                child: PrimaryCard(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: 500),
                    padding: EdgeInsets.all(context.xLargeSpace),
                    child: Form(
                      key: viewModel.formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // padding: EdgeInsets.all(context.smallSpace),
                        children: [
                          Text(
                            "login".translate(context),
                            style: context.textTheme.headlineMedium,
                          ),
                          SizedBox(height: context.mediumSpace),
                          TextFormField(
                            controller: viewModel.email,
                            validator: ValidationBuilder().email().build(),
                            decoration: InputDecoration(
                              hintText: "email".translate(context),
                              // prefixIcon: const Icon(
                              //   HugeIcons.strokeRoundedMail01,
                              // ),
                            ),
                          ),
                          SizedBox(height: context.smallSpace),
                          ValueListenableBuilder(
                            valueListenable: viewModel.isPasswordHidden,
                            builder: (context, isHidden, _) {
                              return TextFormField(
                                controller: viewModel.password,
                                validator:
                                    ValidationBuilder().minLength(5).build(),
                                obscureText: isHidden,
                                decoration: InputDecoration(
                                  // prefixIcon: const Icon(
                                  //   HugeIcons.strokeRoundedKey01,
                                  // ),
                                  hintText: "password".translate(context),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      viewModel.isPasswordHidden.value =
                                          !isHidden;
                                    },
                                    icon: Icon(
                                      isHidden
                                          ? HugeIcons.strokeRoundedViewOffSlash
                                          : HugeIcons.strokeRoundedView,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: context.mediumSpace),
                          Row(
                            children: [
                              Checkbox(
                                value: viewModel.rememberMe,
                                onChanged: viewModel.toggleRememberMe,
                              ),
                              Text(
                                "keep_me_logged_in".translate(context),
                                style: context.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          SizedBox(height: context.mediumSpace),
                          SizedBox(height: context.mediumSpace),
                          AdminElevatedResponsiveButton(
                            controller: viewModel.submitButtonController,
                            onPressed: () {
                              viewModel
                                  .submit(context)
                                  .then(
                                    (value) {
                                      if (value == true) {
                                        Modular.to.navigate(
                                          CoursesModule.construct(
                                            CoursesModule.root,
                                          ),
                                        );
                                      }
                                    },
                                    onError: (error) {
                                      Toast.error(context, error);
                                    },
                                  );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [Text("login".translate(context))],
                            ),
                          ),
                          SizedBox(height: context.mediumSpace),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
